# frozen_string_literal: true

module OpnApi
  # Unified reconfigure handler with registry pattern.
  #
  # Each reconfigure group is registered as a named instance. Callers
  # call mark() to track devices with pending changes, then run() to
  # perform the actual reconfigure. The first run() call performs the
  # work; subsequent calls are no-ops because tracking state is cleared.
  #
  # Error tracking: if any caller marks a device as errored (via mark_error),
  # reconfigure is skipped for that device.
  #
  # @example Register and use a reconfigure group
  #   OpnApi::ServiceReconfigure.register(:ipsec,
  #     endpoint: 'ipsec/service/reconfigure',
  #     log_prefix: 'opn_ipsec')
  #
  #   OpnApi::ServiceReconfigure[:ipsec].mark('opnsense01', client)
  #   results = OpnApi::ServiceReconfigure[:ipsec].run
  #   # => { 'opnsense01' => :ok }
  class ServiceReconfigure
    # Global registry of named instances.
    @registry = {}
    @defaults_loaded = false

    # Registers a new reconfigure group. Idempotent — returns the existing
    # instance if the name is already registered.
    #
    # @param name [Symbol] Unique group identifier (e.g. :haproxy, :ipsec)
    # @param endpoint [String] API endpoint for POST reconfigure call
    # @param log_prefix [String] Prefix for log messages
    # @param configtest_endpoint [String, nil] Optional GET endpoint for configtest.
    #   When set, configtest is run before reconfigure; ALERT results skip reconfigure.
    # @return [ServiceReconfigure] The registered instance
    def self.register(name, endpoint:, log_prefix:, configtest_endpoint: nil)
      @registry[name] ||= new(
        name: name,
        endpoint: endpoint,
        log_prefix: log_prefix,
        configtest_endpoint: configtest_endpoint,
      )
    end

    # Retrieves a registered instance by name. Loads defaults on first access
    # if not already loaded.
    #
    # @param name [Symbol]
    # @return [ServiceReconfigure]
    # @raise [OpnApi::Error] if the name is not registered
    def self.[](name)
      load_defaults! unless @defaults_loaded
      instance = @registry[name]
      raise OpnApi::Error, "ServiceReconfigure: unknown group '#{name}'" unless instance

      instance
    end

    # Returns all registered group names.
    #
    # @return [Array<Symbol>]
    def self.registered_names
      load_defaults! unless @defaults_loaded
      @registry.keys
    end

    # Clears all registrations and instance state.
    def self.reset!
      @registry.each_value(&:clear_state)
      @registry.clear
      @defaults_loaded = false
    end

    # Registers all default OPNsense reconfigure groups.
    # Called automatically on first access via [], but can be called
    # explicitly for eager loading.
    def self.load_defaults!
      return if @defaults_loaded

      @defaults_loaded = true
      register_defaults
    end

    # @return [Symbol] The group name
    attr_reader :name

    # Registers a device as having pending changes. Subsequent calls for
    # the same device are ignored (first client wins).
    #
    # @param device_name [String]
    # @param client [OpnApi::Client]
    def mark(device_name, client)
      @devices_to_reconfigure[device_name] ||= client
    end

    # Registers a device as having a resource evaluation error. Used to
    # suppress reconfigure when the service config may be inconsistent.
    #
    # @param device_name [String]
    def mark_error(device_name)
      @devices_with_errors[device_name] = true
    end

    # Performs reconfigure for all marked devices, then clears state.
    # Returns a result hash per device.
    #
    # @return [Hash{String => Symbol}] Results per device:
    #   :ok — reconfigure succeeded
    #   :skipped — skipped due to error or configtest ALERT
    #   :error — reconfigure call failed
    #   :warning — reconfigure returned unexpected status
    def run
      results = {}
      @devices_to_reconfigure.each do |device_name, client|
        results[device_name] = reconfigure_device(device_name, client)
      end
      clear_state
      results
    end

    # Clears all tracking state (devices + errors).
    def clear_state
      @devices_to_reconfigure.clear
      @devices_with_errors.clear
    end

    private

    def initialize(name:, endpoint:, log_prefix:, configtest_endpoint:)
      @name = name
      @endpoint = endpoint
      @log_prefix = log_prefix
      @configtest_endpoint = configtest_endpoint
      @devices_to_reconfigure = {}
      @devices_with_errors = {}
    end

    # Reconfigures a single device. Returns a status symbol.
    def reconfigure_device(device_name, client)
      # Skip devices with resource evaluation errors
      if @devices_with_errors[device_name]
        OpnApi.logger.error(
          "#{@log_prefix}: skipping reconfigure for '#{device_name}' " \
          'because one or more resources failed to evaluate',
        )
        return :skipped
      end

      # Run configtest if configured (e.g. HAProxy)
      return :skipped if @configtest_endpoint && !run_configtest(device_name, client)

      execute_reconfigure(device_name, client)
    rescue OpnApi::Error => e
      OpnApi.logger.error("#{@log_prefix}: reconfigure of '#{device_name}' failed: #{e.message}")
      :error
    end

    # Runs configtest for a device. Returns true if reconfigure should proceed.
    def run_configtest(device_name, client)
      result      = client.get(@configtest_endpoint)
      test_output = result.is_a?(Hash) ? result['result'].to_s : ''

      if test_output.include?('ALERT')
        OpnApi.logger.error(
          "#{@log_prefix}: configtest for '#{device_name}' reported ALERT, " \
          "skipping reconfigure: #{test_output.strip}",
        )
        return false
      elsif test_output.include?('WARNING')
        OpnApi.logger.warning(
          "#{@log_prefix}: configtest for '#{device_name}' reported WARNING: " \
          "#{test_output.strip}",
        )
      else
        OpnApi.logger.notice("#{@log_prefix}: configtest for '#{device_name}' passed")
      end

      true
    end

    # Executes the reconfigure POST and returns a status symbol.
    def execute_reconfigure(device_name, client)
      reconf = client.post(@endpoint, {})
      status = reconf.is_a?(Hash) ? reconf['status'].to_s.strip.downcase : nil
      if status == 'ok'
        OpnApi.logger.notice("#{@log_prefix}: reconfigure of '#{device_name}' completed")
        :ok
      else
        OpnApi.logger.warning(
          "#{@log_prefix}: reconfigure of '#{device_name}' returned unexpected " \
          "status: #{reconf.inspect}",
        )
        :warning
      end
    end

    # Registers all default OPNsense reconfigure groups (ported from
    # puppet-opn's service_reconfigure_registry.rb).
    def self.register_defaults
      # ACME Client
      register(:acmeclient,
               endpoint: 'acmeclient/service/reconfigure',
               log_prefix: 'opn_acmeclient')

      # Cron jobs
      register(:cron,
               endpoint: 'cron/service/reconfigure',
               log_prefix: 'opn_cron')

      # DHCP Relay
      register(:dhcrelay,
               endpoint: 'dhcrelay/service/reconfigure',
               log_prefix: 'opn_dhcrelay')

      # Firewall aliases
      register(:firewall_alias,
               endpoint: 'firewall/alias/reconfigure',
               log_prefix: 'opn_firewall_alias')

      # Firewall interface groups
      register(:firewall_group,
               endpoint: 'firewall/group/reconfigure',
               log_prefix: 'opn_firewall_group')

      # Firewall rules (uses 'apply' instead of 'reconfigure')
      register(:firewall_rule,
               endpoint: 'firewall/filter/apply',
               log_prefix: 'opn_firewall_rule')

      # Routing gateways
      register(:gateway,
               endpoint: 'routing/settings/reconfigure',
               log_prefix: 'opn_gateway')

      # HAProxy (with configtest before reconfigure)
      register(:haproxy,
               endpoint: 'haproxy/service/reconfigure',
               log_prefix: 'opn_haproxy',
               configtest_endpoint: 'haproxy/service/configtest')

      # HA sync / CARP
      register(:hasync,
               endpoint: 'core/hasync/reconfigure',
               log_prefix: 'opn_hasync')

      # IPsec
      register(:ipsec,
               endpoint: 'ipsec/service/reconfigure',
               log_prefix: 'opn_ipsec')

      # KEA DHCP
      register(:kea,
               endpoint: 'kea/service/reconfigure',
               log_prefix: 'opn_kea')

      # Node Exporter
      register(:node_exporter,
               endpoint: 'nodeexporter/service/reconfigure',
               log_prefix: 'opn_node_exporter')

      # OpenVPN
      register(:openvpn,
               endpoint: 'openvpn/service/reconfigure',
               log_prefix: 'opn_openvpn')

      # Static routes
      register(:route,
               endpoint: 'routes/routes/reconfigure',
               log_prefix: 'opn_route')

      # Syslog
      register(:syslog,
               endpoint: 'syslog/service/reconfigure',
               log_prefix: 'opn_syslog')

      # System tunables (sysctl)
      register(:tunable,
               endpoint: 'core/tunables/reconfigure',
               log_prefix: 'opn_tunable')

      # Zabbix Agent
      register(:zabbix_agent,
               endpoint: 'zabbixagent/service/reconfigure',
               log_prefix: 'opn_zabbix_agent')

      # Zabbix Proxy
      register(:zabbix_proxy,
               endpoint: 'zabbixproxy/service/reconfigure',
               log_prefix: 'opn_zabbix_proxy')
    end
    private_class_method :register_defaults
  end
end
