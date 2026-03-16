# frozen_string_literal: true

require 'json'

module OpnApi
  module CLI
    module Commands
      # CLI commands for generic API calls (GET/POST).
      module Api
        module_function

        # Performs a GET request to an arbitrary API path.
        #
        # @param args [Array<String>] [path]
        # @param opts [Hash] Global CLI options
        # @return [Object] Parsed API response
        def get(args, opts)
          path = args.shift
          raise OpnApi::Error, 'Usage: opn-api get <path>' unless path

          client = Base.build_client(opts)
          client.get(path)
        end

        # Performs a POST request to an arbitrary API path.
        #
        # @param args [Array<String>] [path, optional_json]
        # @param opts [Hash] Global CLI options
        # @return [Object] Parsed API response
        def post(args, opts)
          path = args.shift
          raise OpnApi::Error, 'Usage: opn-api post <path> [json]' unless path

          client = Base.build_client(opts)
          data = parse_post_data(args)
          client.post(path, data)
        end

        # Parses POST data from args or stdin.
        def parse_post_data(args)
          # Inline JSON argument
          json_str = args.shift
          return JSON.parse(json_str) if json_str

          # Stdin
          unless $stdin.tty?
            input = $stdin.read.strip
            return JSON.parse(input) unless input.empty?
          end

          # Default: empty body
          {}
        end
      end
    end
  end
end
