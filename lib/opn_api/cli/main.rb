# frozen_string_literal: true

require 'optparse'
require_relative 'formatter'
require_relative 'commands/base'
require_relative 'commands/api'
require_relative 'commands/backup'
require_relative 'commands/device'
require_relative 'commands/plugin'
require_relative 'commands/reconfigure'
require_relative 'commands/resource'

module OpnApi
  module CLI
    # Main CLI dispatcher. Parses global options, extracts the subcommand,
    # and delegates to the appropriate command module.
    module Main
      COMMANDS = {
        'backup' => { handler: Commands::Backup.method(:download), desc: 'Download config backup' },
        'create' => { handler: Commands::Resource.method(:create), desc: 'Create resource' },
        'delete' => { handler: Commands::Resource.method(:delete), desc: 'Delete resource' },
        'devices' => { handler: Commands::Device.method(:list), desc: 'List configured devices' },
        'get' => { handler: Commands::Api.method(:get), desc: 'GET request to API path' },
        'groups' => { handler: Commands::Reconfigure.method(:groups), desc: 'List reconfigure groups' },
        'install' => { handler: Commands::Plugin.method(:install), desc: 'Install plugin' },
        'plugins' => { handler: Commands::Plugin.method(:list), desc: 'List installed plugins' },
        'post' => { handler: Commands::Api.method(:post), desc: 'POST request to API path' },
        'reconfigure' => { handler: Commands::Reconfigure.method(:run), desc: 'Trigger service reconfigure' },
        'resources' => { handler: Commands::Resource.method(:list), desc: 'List known resource types' },
        'search' => { handler: Commands::Resource.method(:search), desc: 'Search resources' },
        'show' => { handler: Commands::Resource.method(:show), desc: 'Show single resource' },
        'test' => { handler: Commands::Device.method(:test), desc: 'Test device connectivity' },
        'uninstall' => { handler: Commands::Plugin.method(:uninstall), desc: 'Uninstall plugin' },
        'update' => { handler: Commands::Resource.method(:update), desc: 'Update resource' },
      }.freeze

      module_function

      # Main entry point for the CLI.
      #
      # @param argv [Array<String>] Command-line arguments
      # @return [Integer] Exit code (0 = success, 1 = error)
      def run(argv)
        opts = parse_global_options(argv)

        # Show help if no command given
        if argv.empty?
          show_help
          return 0
        end

        command_name = argv.shift
        command = COMMANDS[command_name]

        unless command
          warn("Unknown command: #{command_name}")
          warn("Run 'opn-api --help' for usage information.")
          return 1
        end

        # Configure logging level
        OpnApi.logger = OpnApi::Logger.new(level: opts[:verbose] ? :debug : :info)

        # Execute command and format output
        result = command[:handler].call(argv, opts)
        output = Formatter.format(result, format: opts[:format], fields: opts[:fields],
                                          all_fields: opts[:all_fields],
                                          show_empty: opts[:show_empty])
        puts output unless output.nil? || output.empty?

        0
      rescue OpnApi::ApiError => e
        # Show full API response for debugging
        warn("Error: #{e.message}")
        warn("Response body: #{e.body}") if opts[:verbose] && e.body && !e.body.empty?
        1
      rescue OpnApi::Error => e
        warn("Error: #{e.message}")
        1
      rescue JSON::ParserError => e
        warn("Invalid JSON: #{e.message}")
        1
      end

      # Parses global options from argv (modifies argv in place).
      def parse_global_options(argv)
        opts = { device: 'default', format: :table, verbose: false }

        parser = OptionParser.new do |o|
          o.banner = 'Usage: opn-api [options] <command> [command-options] [args...]'
          o.separator ''
          o.separator 'Global options:'

          o.on('-c', '--config-dir PATH', 'Config directory for device files') do |v|
            opts[:config_dir] = v
          end
          o.on('-d', '--device NAME', 'Device name (default: "default")') do |v|
            opts[:device] = v
          end
          o.on('-f', '--format FORMAT', %w[table json yaml],
               'Output format: table, json, yaml (default: table)') do |v|
            opts[:format] = v.to_sym
          end
          o.on('-F', '--fields FIELDS', 'Comma-separated field names for table output') do |v|
            opts[:fields] = v.split(',').map(&:strip)
          end
          o.on('-A', '--all-fields', 'Show all fields in table output (default: first 5)') do
            opts[:all_fields] = true
          end
          o.on('-E', '--show-empty', 'Show empty fields in table output (default: hidden)') do
            opts[:show_empty] = true
          end
          o.on('-v', '--verbose', 'Enable debug output') do
            opts[:verbose] = true
          end
          o.on('--version', 'Show version') do
            puts "opn-api #{OpnApi::VERSION}"
            exit 0
          end
          o.on('-h', '--help', 'Show help') do
            show_help
            exit 0
          end
        end

        # Parse global options from anywhere in argv (before or after command)
        parser.parse!(argv)
        opts
      end

      # Displays help with available commands.
      def show_help
        puts 'Usage: opn-api [options] <command> [command-options] [args...]'
        puts ''
        puts 'A CLI tool for the OPNsense REST API.'
        puts ''
        puts 'Global options:'
        puts '  -c, --config-dir PATH    Config directory for device files'
        puts '  -d, --device NAME        Device name (default: "default")'
        puts '  -f, --format FORMAT      Output format: table, json, yaml (default: table)'
        puts '  -F, --fields FIELDS      Comma-separated field names for table output'
        puts '  -A, --all-fields         Show all fields in table output (default: first 5)'
        puts '  -E, --show-empty         Show empty fields in table output (default: hidden)'
        puts '  -v, --verbose            Enable debug output (includes API error details)'
        puts '  --version                Show version'
        puts '  -h, --help               Show this help'
        puts ''
        puts 'Commands:'
        max_len = COMMANDS.keys.map(&:length).max
        COMMANDS.each do |name, cmd|
          puts "  #{name.ljust(max_len)}  #{cmd[:desc]}"
        end
        puts ''
        puts 'Resource commands (search, show, create, update, delete) accept a resource'
        puts 'name from the registry (e.g. "haproxy_server") or raw module/controller/type.'
        puts 'Run "opn-api resources" for a list of known resource types.'
      end
    end
  end
end
