# frozen_string_literal: true

module OpnApi
  module CLI
    module Commands
      # CLI commands for service reconfigure operations.
      module Reconfigure
        module_function

        # Lists all registered reconfigure groups.
        #
        # @param _args [Array<String>] Unused
        # @param _opts [Hash] Unused
        # @return [Array<Hash>] Group information
        def groups(_args, _opts)
          OpnApi::ServiceReconfigure.registered_names.sort.map do |name|
            OpnApi::ServiceReconfigure[name]
            { 'group' => name.to_s }
          end
        end

        # Triggers reconfigure for a specific group on a device.
        # Usage: opn-api reconfigure <group>
        #
        # @param args [Array<String>] [group_name]
        # @param opts [Hash] Global CLI options
        # @return [Hash] Reconfigure results
        def run(args, opts)
          group_name = args.shift
          raise OpnApi::Error, 'Usage: opn-api reconfigure <group>' unless group_name

          client = Base.build_client(opts)
          group = OpnApi::ServiceReconfigure[group_name.to_sym]
          group.mark(opts[:device], client)
          group.run
        end
      end
    end
  end
end
