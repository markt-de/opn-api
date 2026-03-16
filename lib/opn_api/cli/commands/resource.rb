# frozen_string_literal: true

module OpnApi
  module CLI
    module Commands
      # CLI commands for structured resource CRUD operations.
      #
      # Resources can be specified in two ways:
      # 1. Registry name (preferred): opn-api search haproxy_server
      # 2. Raw module/controller/type: opn-api search haproxy settings search_servers
      #
      # The registry handles the inconsistent OPNsense endpoint naming
      # (plural search, camelCase, bare names) transparently.
      #
      # Singleton resources (settings) are auto-detected from the registry
      # and work without UUID for show/update.
      module Resource
        module_function

        # Searches for resources.
        # Usage: opn-api search <resource_name>
        #        opn-api search <module> <controller> <type>
        #
        # @param args [Array<String>] Resource name or [module, controller, type]
        # @param opts [Hash] Global CLI options
        # @return [Object] Search results
        def search(args, opts)
          resource_name = args.first
          res = build_resource(args, opts, 'search')
          result = res.search
          return result unless res.singleton

          # Singleton: unwrap, filter, normalize (same as show)
          result = result.values.first if result.is_a?(Hash) && result.length == 1 && result.values.first.is_a?(Hash)
          result = filter_singleton_response(resource_name, result) if result.is_a?(Hash)
          OpnApi::Normalize.normalize_config(result)
        end

        # Shows a single resource by UUID, or a singleton settings resource.
        # Usage: opn-api show <resource_name> <uuid>
        #        opn-api show <singleton_resource>
        #
        # @param args [Array<String>] Resource name + uuid, or singleton name
        # @param opts [Hash] Global CLI options
        # @return [Hash] Resource data
        def show(args, opts)
          # Capture resource name before it's shifted from args
          resource_name = args.first
          res, remaining = build_resource_with_remainder(args, opts, 'show')

          result = if res.singleton
                     res.show_settings
                   else
                     uuid = remaining.shift
                     raise OpnApi::Error, "Usage: opn-api show <resource> <uuid>\n#{registry_hint}" unless uuid

                     res.get(uuid)
                   end

          # Unwrap single-key response (e.g. {"alias": {...}} → inner hash)
          result = result.values.first if result.is_a?(Hash) && result.length == 1 && result.values.first.is_a?(Hash)

          # Filter singleton response to settings-only keys (matching puppet-opn behavior)
          result = filter_singleton_response(resource_name, result) if res.singleton && result.is_a?(Hash)

          # Normalize selection hashes for human-readable output
          OpnApi::Normalize.normalize_config(result)
        end

        # Creates a new resource.
        # Usage: opn-api create <resource_name> [-j json | stdin]
        #
        # @param args [Array<String>] Resource name, then JSON
        # @param opts [Hash] Global CLI options
        # @return [Hash] API response
        def create(args, opts)
          res, remaining = build_resource_with_remainder(args, opts, 'create')
          raise OpnApi::Error, 'Singleton resources do not support create. Use update instead.' if res.singleton

          data = Base.read_json_input(remaining)
          result = res.add(data)
          check_result(result, 'create', args)
          result
        end

        # Updates an existing resource by UUID, or a singleton settings resource.
        # Usage: opn-api update <resource_name> <uuid> [-j json | stdin]
        #        opn-api update <singleton_resource> [-j json | stdin]
        #
        # @param args [Array<String>] Resource + uuid, then JSON
        # @param opts [Hash] Global CLI options
        # @return [Hash] API response
        def update(args, opts)
          res, remaining = build_resource_with_remainder(args, opts, 'update')

          if res.singleton
            data = Base.read_json_input(remaining)
            result = res.update_settings(data)
          else
            uuid = remaining.shift
            raise OpnApi::Error, "Usage: opn-api update <resource> <uuid> -j '<json>'" unless uuid

            data = Base.read_json_input(remaining)
            result = res.set(uuid, data)
          end

          check_result(result, 'update', args)
          result
        end

        # Deletes a resource by UUID.
        # Usage: opn-api delete <resource_name> <uuid>
        #
        # @param args [Array<String>] Resource + uuid
        # @param opts [Hash] Global CLI options
        # @return [Hash] API response
        def delete(args, opts)
          res, remaining = build_resource_with_remainder(args, opts, 'delete')
          raise OpnApi::Error, 'Singleton resources do not support delete.' if res.singleton

          uuid = remaining.shift
          raise OpnApi::Error, 'Usage: opn-api delete <resource> <uuid>' unless uuid

          result = res.del(uuid)
          check_result(result, 'delete', args)
          result
        end

        # Lists all known resource types from the registry.
        # Usage: opn-api resources
        #
        # @param _args [Array<String>] Unused
        # @param _opts [Hash] Unused
        # @return [Array<Hash>] Resource type information
        def list(_args, _opts)
          OpnApi::ResourceRegistry.names.map do |name|
            entry = OpnApi::ResourceRegistry.lookup(name)
            type = entry[:singleton] ? 'singleton' : 'crud'
            { 'resource' => name, 'wrapper_key' => entry[:wrapper].to_s, 'type' => type }
          end
        end

        # Checks the API result for failure and raises with the full API response.
        def check_result(result, action, args)
          return unless result.is_a?(Hash)

          status = (result['result'] || result['status']).to_s.strip.downcase
          return unless status == 'failed'

          msg = "#{action} failed: #{JSON.generate(result)}"

          # When OPNsense returns only {"result":"failed"} without validation
          # details, the most common cause is a wrong wrapper key in the JSON body.
          if result.keys == ['result']
            wrapper_hint = detect_wrapper_key(args)
            msg += "\nHint: The JSON wrapper key is likely wrong. "
            msg += "Expected wrapper key: '#{wrapper_hint}'. " if wrapper_hint
            msg += 'The endpoint type is NOT the wrapper key. ' unless wrapper_hint
            msg += 'Use "opn-api show -f json" on an existing resource to find the correct wrapper key. '
            msg += 'Use -v for full request/response details.'
          end

          raise OpnApi::Error, msg
        end

        # Tries to detect the correct wrapper key from args.
        def detect_wrapper_key(args)
          name = args.is_a?(Array) ? args.first : nil
          return nil unless name

          entry = OpnApi::ResourceRegistry.lookup(name)
          entry&.dig(:wrapper)
        end

        # Builds a Resource from args.
        def build_resource(args, opts, command)
          build_resource_with_remainder(args, opts, command).first
        end

        # Builds a Resource and returns [resource, remaining_args].
        # Tries registry lookup first, then raw mode.
        def build_resource_with_remainder(args, opts, command)
          raise OpnApi::Error, "Usage: opn-api #{command} <resource>\n#{registry_hint}" if args.empty?

          client = Base.build_client(opts)

          # Try registry lookup (single arg)
          entry = OpnApi::ResourceRegistry.lookup(args.first)
          if entry
            name = args.shift
            res = OpnApi::ResourceRegistry.build(client, name)
            return [res, args]
          end

          # Fallback: raw module/controller/type (three args)
          if args.length >= 3 && !args[0].start_with?('-')
            mod = args.shift
            ctrl = args.shift
            type = args.shift
            res = OpnApi::Resource.new(
              client: client,
              module_name: mod,
              controller: ctrl,
              resource_type: type,
            )
            return [res, args]
          end

          raise OpnApi::Error,
                "Unknown resource: '#{args.first}'. " \
                "Run 'opn-api resources' for known types, or use three args: <module> <controller> <type>"
        end

        # Filters a singleton response to only include settings keys,
        # excluding sub-resource data. Matches puppet-opn behavior:
        # - response_dig with 1 element → dig into that sub-key
        # - response_dig with 2+ elements → slice those keys
        # - response_reject → reject those keys
        # - neither → return unfiltered
        def filter_singleton_response(resource_name, result)
          entry = OpnApi::ResourceRegistry.lookup(resource_name)
          return result unless entry

          if entry[:response_dig]
            keys = entry[:response_dig]
            if keys.length == 1
              # Single key: dig into sub-key (e.g. acmeclient → settings)
              result[keys.first] || result
            else
              # Multiple keys: slice those settings sections
              result.slice(*keys)
            end
          elsif entry[:response_reject]
            # Reject sub-resource keys (e.g. zabbix_agent → reject aliases, userparameters)
            result.except(*entry[:response_reject])
          else
            result
          end
        end

        # Hint text for error messages.
        def registry_hint
          "Run 'opn-api resources' for a list of known resource types."
        end
      end
    end
  end
end
