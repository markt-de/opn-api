# frozen_string_literal: true

module OpnApi
  module CLI
    module Commands
      # Shared helpers for all CLI commands.
      module Base
        # Creates an OpnApi::Config from global options.
        #
        # @param opts [Hash] Global CLI options
        # @return [OpnApi::Config]
        def self.build_config(opts)
          OpnApi::Config.new(config_dir: opts[:config_dir])
        end

        # Creates an OpnApi::Client for the device specified in global options.
        #
        # @param opts [Hash] Global CLI options (must include :device)
        # @return [OpnApi::Client]
        def self.build_client(opts)
          config = build_config(opts)
          config.client_for(opts[:device])
        end

        # Reads JSON input from -j argument or stdin.
        #
        # @param args [Array<String>] Remaining CLI args
        # @return [Hash] Parsed JSON
        def self.read_json_input(args)
          # Check for -j flag in remaining args
          json_idx = args.index('-j')
          if json_idx
            json_str = args[json_idx + 1]
            raise OpnApi::Error, 'Missing JSON data after -j' unless json_str

            return JSON.parse(json_str)
          end

          # Read from stdin if not a TTY
          unless $stdin.tty?
            input = $stdin.read.strip
            return JSON.parse(input) unless input.empty?
          end

          raise OpnApi::Error, 'No JSON input provided (use -j or pipe via stdin)'
        end
      end
    end
  end
end
