# frozen_string_literal: true

module OpnApi
  module CLI
    module Commands
      # CLI commands for device management.
      module Device
        module_function

        # Lists all configured devices.
        #
        # @param _args [Array<String>] Unused
        # @param opts [Hash] Global CLI options
        # @return [Object] Formatted output data
        def list(_args, opts)
          config = Base.build_config(opts)
          names = config.device_names
          return '(no devices configured)' if names.empty?

          names.map { |n| { 'device' => n, 'config' => config.device_path(n) } }
        end

        # Tests connectivity to one or all devices.
        #
        # @param args [Array<String>] Optional device name
        # @param opts [Hash] Global CLI options
        # @return [Object] Formatted output data
        def test(args, opts)
          config = Base.build_config(opts)
          names = args.empty? ? config.device_names : [args.first]
          results = []

          names.each do |name|
            result = { 'device' => name }
            begin
              client = config.client_for(name)
              # Call a lightweight endpoint to check connectivity
              info = client.get('core/firmware/info')
              result['status'] = 'ok'
              result['version'] = info['product_version'].to_s if info['product_version']
            rescue OpnApi::Error => e
              result['status'] = 'error'
              result['message'] = e.message
            end
            results << result
          end

          results
        end
      end
    end
  end
end
