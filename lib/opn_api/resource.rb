# frozen_string_literal: true

module OpnApi
  # Generic CRUD wrapper for OPNsense API resources.
  #
  # Supports three resource patterns:
  #
  # 1. Standard CRUD (search/get/add/set/del with UUID)
  # 2. Singleton settings (GET get / POST set, no UUID, no search/add/del)
  # 3. Resources with GET-based search (e.g. snapshots, trust_crl)
  #
  # @example Via ResourceRegistry (preferred)
  #   res = OpnApi::ResourceRegistry.build(client, 'haproxy_server')
  #   res.search
  #
  # @example Direct with explicit paths
  #   res = OpnApi::Resource.new(
  #     client: client,
  #     base_path: 'haproxy/settings',
  #     search_action: 'search_servers',
  #     crud_action: '%{action}_server',
  #   )
  #
  # @example Singleton settings resource
  #   res = OpnApi::Resource.new(
  #     client: client,
  #     base_path: 'zabbixagent/settings',
  #     search_action: 'get',
  #     crud_action: '%{action}',
  #     singleton: true,
  #     search_method: :get,
  #   )
  #   config = res.show_settings  # GET zabbixagent/settings/get
  #   res.update_settings(config)   # POST zabbixagent/settings/set
  class Resource
    attr_reader :singleton

    # @param client [OpnApi::Client] API client instance
    # @param base_path [String] Base path (e.g. 'haproxy/settings')
    # @param search_action [String] Search action name (e.g. 'search_servers')
    # @param crud_action [String] CRUD action template with %{action} placeholder
    # @param singleton [Boolean] True for settings resources (no UUID, no search/add/del)
    # @param search_method [Symbol] HTTP method for search (:post or :get)
    # @param module_name [String] Legacy: OPNsense module (e.g. 'firewall')
    # @param controller [String] Legacy: OPNsense controller (e.g. 'alias')
    # @param resource_type [String] Legacy: Resource type (e.g. 'item')
    def initialize(client:, base_path: nil, search_action: nil, crud_action: nil,
                   singleton: false, search_method: :post,
                   module_name: nil, controller: nil, resource_type: nil)
      @client = client
      @singleton = singleton
      @search_method = search_method

      if base_path
        # Explicit path mode
        @base_path = base_path
        @search_action = search_action
        @crud_action = crud_action
      else
        # Legacy module/controller/type mode
        @base_path = "#{module_name}/#{controller}"
        suffix = resource_type.to_s.empty? ? '' : "_#{resource_type}"
        @search_action = "search#{suffix}"
        @crud_action = "%{action}#{suffix}"
      end
    end

    # Searches for resources matching the given parameters.
    #
    # @param params [Hash] Search parameters (passed as POST body, ignored for GET)
    # @return [Object] Search results (Array<Hash> for standard, Hash for singletons)
    def search(params = {})
      path = "#{@base_path}/#{@search_action}"
      result = if @search_method == :get
                 @client.get(path)
               else
                 @client.post(path, params)
               end
      # Singletons return the full response hash (settings structure).
      # All other searches extract the rows array.
      return result if @singleton

      result.is_a?(Hash) ? (result['rows'] || []) : result
    end

    # Retrieves a single resource by UUID.
    #
    # @param uuid [String]
    # @return [Hash] Resource data
    def get(uuid)
      @client.get("#{@base_path}/#{crud_path('get')}/#{uuid}")
    end

    # Retrieves a singleton settings resource (no UUID).
    #
    # @return [Hash] Resource data
    def show_settings
      @client.get("#{@base_path}/#{crud_path('get')}")
    end

    # Creates a new resource.
    #
    # @param config [Hash] Resource configuration (wrapped in wrapper key)
    # @return [Hash] API response (typically includes 'uuid' on success)
    def add(config)
      @client.post("#{@base_path}/#{crud_path('add')}", config)
    end

    # Updates an existing resource.
    #
    # @param uuid [String]
    # @param config [Hash] Resource configuration
    # @return [Hash] API response
    def set(uuid, config)
      @client.post("#{@base_path}/#{crud_path('set')}/#{uuid}", config)
    end

    # Updates a singleton settings resource (no UUID).
    #
    # @param config [Hash] Resource configuration
    # @return [Hash] API response
    def update_settings(config)
      @client.post("#{@base_path}/#{crud_path('set')}", config)
    end

    # Deletes a resource by UUID.
    #
    # @param uuid [String]
    # @return [Hash] API response
    def del(uuid)
      @client.post("#{@base_path}/#{crud_path('del')}/#{uuid}", {})
    end

    private

    # Builds a CRUD action path from the template.
    # e.g. crud_path('get') with template '%{action}_server' → 'get_server'
    def crud_path(action)
      format(@crud_action, action: action)
    end
  end
end
