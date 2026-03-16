# frozen_string_literal: true

module OpnApi
  module CLI
    module Commands
      # CLI command for downloading OPNsense config backups.
      #
      # The backup endpoint returns XML (not JSON), so this uses
      # the client's raw mode to skip JSON parsing.
      module Backup
        module_function

        # Downloads the OPNsense config backup (XML).
        # Usage: opn-api backup [output_path]
        #
        # With output_path: writes XML to file, returns status hash.
        # Without output_path: returns raw XML string (printed to stdout).
        #
        # @param args [Array<String>] [optional output_path]
        # @param opts [Hash] Global CLI options
        # @return [Hash, String] Status hash or raw XML data
        def download(args, opts)
          client = Base.build_client(opts)
          data = client.get('core/backup/download/this', raw: true)

          output_path = args.shift
          if output_path
            File.write(output_path, data)
            { 'status' => 'ok', 'file' => output_path, 'size' => data.bytesize }
          else
            # Without output path: raw data directly to stdout
            data
          end
        end
      end
    end
  end
end
