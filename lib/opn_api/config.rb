# frozen_string_literal: true

require 'yaml'

module OpnApi
  # Configuration loader for OPNsense device credentials.
  #
  # Searches for per-device YAML files in a config directory hierarchy.
  # Each YAML file contains connection details for one OPNsense device.
  #
  # Search order (lowest → highest priority):
  # 1. /etc/opn-api/devices/          (system-wide)
  # 2. ~/.config/opn-api/devices/     (per-user)
  # 3. Explicit config_dir parameter  (programmatic / CLI)
  # 4. OPN_API_CONFIG_DIR env var     (environment override)
  #
  # Device YAML format (compatible with puppet-opn):
  #   url: https://192.168.1.1/api
  #   api_key: +ABC...
  #   api_secret: +XYZ...
  #   ssl_verify: false
  #   timeout: 60
  #
  # @example
  #   config = OpnApi::Config.new
  #   config.device_names            # => ['opnsense01', 'backup']
  #   client = config.client_for('opnsense01')
  #
  # @example With explicit path (e.g. for puppet-opn integration)
  #   config = OpnApi::Config.new(config_dir: '/etc/puppetlabs/puppet/opn')
  #   client = config.client_for('opnsense01')
  class Config
    SYSTEM_DIR = '/etc/opn-api/devices'
    USER_DIR   = File.join(Dir.home, '.config', 'opn-api', 'devices')

    # @param config_dir [String, nil] Explicit device config directory.
    #   Overrides the default search hierarchy (but not OPN_API_CONFIG_DIR).
    def initialize(config_dir: nil)
      @config_dir = resolve_config_dir(config_dir)
    end

    # Returns all available device names found in the config directory.
    #
    # @return [Array<String>] Sorted list of device names
    def device_names
      return [] unless @config_dir && Dir.exist?(@config_dir)

      Dir.glob(File.join(@config_dir, '*.yaml')).map do |f|
        File.basename(f, '.yaml')
      end.sort
    end

    # Returns the configuration hash for a named device.
    #
    # @param name [String] Device name (filename without .yaml extension)
    # @return [Hash] Device config (url, api_key, api_secret, ssl_verify, timeout)
    # @raise [OpnApi::ConfigError] if config file is missing or malformed
    def device(name)
      path = device_path(name)
      unless File.exist?(path)
        raise OpnApi::ConfigError,
              "Config file not found for device '#{name}': #{path}"
      end

      config = YAML.safe_load_file(path)
      unless config.is_a?(Hash)
        raise OpnApi::ConfigError,
              "Config file '#{path}' is not a valid YAML hash"
      end

      config
    end

    # Creates a Client instance for the named device.
    #
    # @param name [String] Device name
    # @return [OpnApi::Client]
    # @raise [OpnApi::ConfigError] if config is missing or malformed
    def client_for(name)
      cfg = device(name)
      OpnApi::Client.new(
        url: cfg['url'] || OpnApi::Client::DEFAULT_URL,
        api_key: cfg['api_key'].to_s,
        api_secret: cfg['api_secret'].to_s,
        ssl_verify: cfg.fetch('ssl_verify', true),
        timeout: cfg.fetch('timeout', 60),
      )
    end

    # Returns the full path to a device config file.
    #
    # @param name [String] Device name
    # @return [String]
    def device_path(name)
      File.join(@config_dir, "#{name}.yaml")
    end

    private

    # Resolves the effective config directory from env, explicit arg, or defaults.
    # Priority: OPN_API_CONFIG_DIR > explicit config_dir > first existing default dir
    def resolve_config_dir(explicit_dir)
      env_dir = ENV.fetch('OPN_API_CONFIG_DIR', nil)
      return env_dir if env_dir && !env_dir.empty?
      return explicit_dir if explicit_dir

      # Use the first default directory that exists, or fall back to USER_DIR
      [USER_DIR, SYSTEM_DIR].find { |d| Dir.exist?(d) } || USER_DIR
    end
  end
end
