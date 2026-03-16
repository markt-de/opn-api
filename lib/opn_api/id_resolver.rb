# frozen_string_literal: true

module OpnApi
  # Resolves ModelRelationField UUIDs/IDs <-> names for OPNsense resources.
  #
  # Maintains a per-run class-level cache keyed by
  # "device:endpoint:id_field:name_field" to avoid redundant API calls.
  #
  # Supports:
  # - Standard UUID fields (ModelRelationField) — id_field: 'uuid', name_field: 'name'
  # - Certificate fields (CertificateField) — id_field: 'refid', name_field: 'descr'
  # - Cron job fields — id_field: 'uuid', name_field: 'description'
  # - Dot-path fields for nested configs — e.g. 'general.stats.allowedUsers'
  #
  # @example
  #   relation_fields = {
  #     'linkedServers' => { endpoint: 'haproxy/settings/search_servers', multiple: true },
  #     'sslCA' => { endpoint: 'trust/ca/search', id_field: 'refid', name_field: 'descr' },
  #   }
  #   translated = OpnApi::IdResolver.translate_to_names(client, 'myfw', relation_fields, config)
  module IdResolver
    UUID_RE = %r{\A[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\z}

    @cache = {}

    # Queries the given endpoint once and builds id<->name maps.
    # Subsequent calls for the same cache key are no-ops.
    #
    # @param client [OpnApi::Client]
    # @param device [String]
    # @param endpoint [String]
    # @param id_field [String] Field containing the ID (default: 'uuid')
    # @param name_field [String] Field containing the display name (default: 'name')
    # @param method [Symbol] HTTP method to use (default: :post)
    def self.populate(client, device, endpoint, id_field: 'uuid', name_field: 'name', method: :post)
      key = cache_key(device, endpoint, id_field, name_field)
      return if @cache.key?(key)

      id_to_name = {}
      name_to_id = {}
      begin
        response = method == :get ? client.get(endpoint) : client.post(endpoint, {})
        rows = response['rows'] || []
        rows.each do |row|
          id   = row[id_field].to_s
          name = row[name_field].to_s
          next if id.empty? || name.empty?

          id_to_name[id] = name
          name_to_id[name] = id
        end
      rescue OpnApi::Error => e
        OpnApi.logger.warning(
          "IdResolver: failed to populate '#{endpoint}' " \
          "for '#{device}': #{e.message}",
        )
      end

      @cache[key] = { id_to_name: id_to_name, name_to_id: name_to_id }
    end

    # Returns a deep copy of +config+ with each relation-field value translated
    # from IDs to names. Falls back to the original value if not found.
    # Supports dot-path field names for nested config hashes.
    #
    # @param client [OpnApi::Client]
    # @param device [String]
    # @param relation_fields [Hash] field_name => { endpoint:, multiple:, ... }
    # @param config [Hash]
    # @return [Hash]
    def self.translate_to_names(client, device, relation_fields, config)
      result = deep_dup(config)
      relation_fields.each do |field, opts|
        id_field    = opts[:id_field]   || 'uuid'
        name_field  = opts[:name_field] || 'name'
        http_method = opts[:method]     || :post

        parent, last_key = dig_path(result, field)
        next unless parent

        value = parent[last_key]
        next if value.nil? || value.to_s.empty?

        populate(client, device, opts[:endpoint],
                 id_field: id_field, name_field: name_field, method: http_method)
        entry = @cache[cache_key(device, opts[:endpoint], id_field, name_field)] || {}
        map = entry[:id_to_name] || {}

        parent[last_key] = if opts[:multiple]
                             value.to_s.split(',').map do |item|
                               item = item.strip
                               map[item] || item
                             end.join(',')
                           else
                             map[value.to_s] || value.to_s
                           end
      end
      result
    end

    # Returns a deep copy of +config+ with each relation-field value translated
    # from names to IDs. Raises ResolveError if a name cannot be resolved.
    # Values that are already valid IDs pass through unchanged.
    # Supports dot-path field names for nested config hashes.
    #
    # @param client [OpnApi::Client]
    # @param device [String]
    # @param relation_fields [Hash] field_name => { endpoint:, multiple:, ... }
    # @param config [Hash]
    # @return [Hash]
    def self.translate_to_uuids(client, device, relation_fields, config)
      result = deep_dup(config)
      relation_fields.each do |field, opts|
        id_field    = opts[:id_field]   || 'uuid'
        name_field  = opts[:name_field] || 'name'
        http_method = opts[:method]     || :post

        parent, last_key = dig_path(result, field)
        next unless parent

        value = parent[last_key]
        next if value.nil? || value.to_s.empty?

        key = cache_key(device, opts[:endpoint], id_field, name_field)
        populate(client, device, opts[:endpoint],
                 id_field: id_field, name_field: name_field, method: http_method)
        entry = @cache[key] || {}
        id_to_name = entry[:id_to_name] || {}

        parent[last_key] = if opts[:multiple]
                             value.to_s.split(',').map do |item|
                               item = item.strip
                               # Already a known ID — pass through
                               next item if id_to_name.key?(item)
                               # Looks like a UUID — pass through
                               next item if UUID_RE.match?(item)

                               resolve_with_retry(
                                 client, device, opts[:endpoint],
                                 id_field, name_field, http_method, item
                               )
                             end.join(',')
                           else
                             str = value.to_s
                             if id_to_name.key?(str) || UUID_RE.match?(str)
                               str
                             else
                               resolve_with_retry(
                                 client, device, opts[:endpoint],
                                 id_field, name_field, http_method, str
                               )
                             end
                           end
      end
      result
    end

    # Clears all cached mappings. Call between runs or in tests.
    def self.reset!
      @cache.clear
    end

    # Navigates a dotted field path in a hash and returns [parent, last_key].
    # For 'stats.allowedUsers' on { 'stats' => { 'allowedUsers' => 'x' } }
    # returns [{ 'allowedUsers' => 'x' }, 'allowedUsers'].
    # For simple fields like 'defaultBackend', returns [hash, 'defaultBackend'].
    # Returns [nil, nil] if any intermediate key is missing.
    def self.dig_path(hash, dotted_field)
      parts = dotted_field.split('.')
      parent = hash
      parts[0..-2].each do |part|
        parent = parent[part]
        return [nil, nil] unless parent.is_a?(Hash)
      end
      [parent, parts.last]
    end

    # Deep-duplicates a Hash/Array structure.
    def self.deep_dup(obj)
      case obj
      when Hash
        obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
      when Array
        obj.map { |v| deep_dup(v) }
      else
        obj
      end
    end

    # Builds a cache key from device, endpoint, id_field, and name_field.
    def self.cache_key(device, endpoint, id_field, name_field)
      "#{device}:#{endpoint}:#{id_field}:#{name_field}"
    end
    private_class_method :cache_key

    # Attempts to resolve a name to an ID, retrying once with a cache refresh.
    # Raises ResolveError if the name cannot be found after retry.
    def self.resolve_with_retry(client, device, endpoint, id_field, name_field, http_method, name)
      key = cache_key(device, endpoint, id_field, name_field)
      entry = @cache[key] || {}
      name_to_id = entry[:name_to_id] || {}

      resolved = name_to_id[name]
      unless resolved
        # Cache miss — refresh and try once more
        @cache.delete(key)
        populate(client, device, endpoint,
                 id_field: id_field, name_field: name_field, method: http_method)
        entry = @cache[key] || {}
        name_to_id = entry[:name_to_id] || {}
        resolved = name_to_id[name]
      end
      unless resolved
        raise OpnApi::ResolveError,
              "IdResolver: cannot resolve '#{name}' to an ID " \
              "via '#{endpoint}' on '#{device}'"
      end
      resolved
    end
    private_class_method :resolve_with_retry
  end
end
