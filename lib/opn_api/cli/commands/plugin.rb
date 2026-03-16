# frozen_string_literal: true

module OpnApi
  module CLI
    module Commands
      # CLI commands for OPNsense plugin management.
      #
      # Plugins use the firmware API which does not follow the standard
      # CRUD pattern. These commands provide a user-friendly interface.
      module Plugin
        module_function

        # Lists installed plugins.
        # Usage: opn-api plugins
        #
        # Fetches the firmware info and filters for installed os-* packages.
        #
        # @param _args [Array<String>] Unused
        # @param opts [Hash] Global CLI options
        # @return [Array<Hash>] List of installed plugins
        def list(_args, opts)
          client = Base.build_client(opts)
          info = client.get('core/firmware/info')
          packages = info['package'] || []

          # Filter for installed plugin packages (os-* naming convention)
          packages.select { |p| p['installed'] == '1' && p['name'].to_s.start_with?('os-') }
                  .map do |p|
                    {
                      'name' => p['name'],
                      'version' => p['version'],
                      'comment' => p['comment'],
                    }
                  end
        end

        # Installs a plugin.
        # Usage: opn-api install <plugin_name>
        #
        # @param args [Array<String>] [plugin_name]
        # @param opts [Hash] Global CLI options
        # @return [Hash] API response
        def install(args, opts)
          name = args.shift
          raise OpnApi::Error, 'Usage: opn-api install <plugin_name>' unless name

          client = Base.build_client(opts)
          client.post("core/firmware/install/#{name}", {})
        end

        # Uninstalls a plugin.
        # Usage: opn-api uninstall <plugin_name>
        #
        # @param args [Array<String>] [plugin_name]
        # @param opts [Hash] Global CLI options
        # @return [Hash] API response
        def uninstall(args, opts)
          name = args.shift
          raise OpnApi::Error, 'Usage: opn-api uninstall <plugin_name>' unless name

          client = Base.build_client(opts)
          client.post("core/firmware/remove/#{name}", {})
        end
      end
    end
  end
end
