# frozen_string_literal: true

module OpnApi
  # Registry of known OPNsense resource types with their exact API endpoints.
  #
  # OPNsense has no consistent endpoint naming convention — some use snake_case
  # with plural search (search_servers/add_server), others use camelCase
  # (searchConnection/addConnection), and some use bare names (search/add).
  # This registry maps user-friendly resource names to the correct API paths.
  #
  # Resource names follow the puppet-opn naming convention (opn_ prefix stripped).
  #
  # Each entry defines:
  # - base_path: module/controller prefix (e.g. 'haproxy/settings')
  # - search_action: full action name for search (e.g. 'search_servers')
  # - crud_action: template for get/add/set/del — `%{action}` is replaced
  #   (e.g. '%{action}_server' → 'get_server', 'add_server')
  # - wrapper: POST body wrapper key (e.g. 'server')
  # - singleton: true for settings resources (GET get / POST set, no UUID)
  # - search_method: :get for resources using GET instead of POST for search
  # - response_dig: keys to extract from GET response after unwrapping.
  #   Single-element array → dig into that sub-key (e.g. ['settings']).
  #   Multi-element array → slice those keys (e.g. ['general', 'maintenance']).
  # - response_reject: keys to exclude from GET response (e.g. sub-resource data).
  #
  # @example
  #   entry = OpnApi::ResourceRegistry.lookup('haproxy_server')
  #   entry[:base_path]     # => 'haproxy/settings'
  #   entry[:search_action] # => 'search_servers'
  module ResourceRegistry
    # Resource definitions keyed by puppet-opn name (without opn_ prefix).
    RESOURCES = {
      # --- ACME Client ---
      'acmeclient_account' => {
        base_path: 'acmeclient/accounts', search_action: 'search',
        crud_action: '%{action}', wrapper: 'account'
      },
      'acmeclient_action' => {
        base_path: 'acmeclient/actions', search_action: 'search',
        crud_action: '%{action}', wrapper: 'action'
      },
      'acmeclient_certificate' => {
        base_path: 'acmeclient/certificates', search_action: 'search',
        crud_action: '%{action}', wrapper: 'certificate'
      },
      'acmeclient_settings' => {
        base_path: 'acmeclient/settings', search_action: 'get',
        crud_action: '%{action}', wrapper: 'acmeclient',
        singleton: true, search_method: :get,
        response_dig: ['settings']
      },
      'acmeclient_validation' => {
        base_path: 'acmeclient/validations', search_action: 'search',
        crud_action: '%{action}', wrapper: 'validation'
      },
      # --- Cron ---
      'cron' => {
        base_path: 'cron/settings', search_action: 'search_jobs',
        crud_action: '%{action}_job', wrapper: 'job'
      },
      # --- DHC Relay ---
      'dhcrelay' => {
        base_path: 'dhcrelay/settings', search_action: 'search_relay',
        crud_action: '%{action}_relay', wrapper: 'relay'
      },
      'dhcrelay_destination' => {
        base_path: 'dhcrelay/settings', search_action: 'search_dest',
        crud_action: '%{action}_dest', wrapper: 'destination'
      },
      # --- Firewall ---
      'firewall_alias' => {
        base_path: 'firewall/alias', search_action: 'search_item',
        crud_action: '%{action}_item', wrapper: 'alias'
      },
      'firewall_category' => {
        base_path: 'firewall/category', search_action: 'search_item',
        crud_action: '%{action}_item', wrapper: 'category'
      },
      'firewall_group' => {
        base_path: 'firewall/group', search_action: 'search_item',
        crud_action: '%{action}_item', wrapper: 'group'
      },
      'firewall_rule' => {
        base_path: 'firewall/filter', search_action: 'search_rule',
        crud_action: '%{action}_rule', wrapper: 'rule'
      },
      # --- Gateway ---
      'gateway' => {
        base_path: 'routing/settings', search_action: 'searchGateway',
        crud_action: '%{action}Gateway', wrapper: 'gateway_item'
      },
      # --- Group (auth) ---
      'group' => {
        base_path: 'auth/group', search_action: 'search',
        crud_action: '%{action}', wrapper: 'group'
      },
      # --- HAProxy ---
      'haproxy_acl' => {
        base_path: 'haproxy/settings', search_action: 'search_acls',
        crud_action: '%{action}_acl', wrapper: 'acl'
      },
      'haproxy_action' => {
        base_path: 'haproxy/settings', search_action: 'search_actions',
        crud_action: '%{action}_action', wrapper: 'action'
      },
      'haproxy_backend' => {
        base_path: 'haproxy/settings', search_action: 'search_backends',
        crud_action: '%{action}_backend', wrapper: 'backend'
      },
      'haproxy_cpu' => {
        base_path: 'haproxy/settings', search_action: 'search_cpus',
        crud_action: '%{action}_cpu', wrapper: 'cpu'
      },
      'haproxy_errorfile' => {
        base_path: 'haproxy/settings', search_action: 'search_errorfiles',
        crud_action: '%{action}_errorfile', wrapper: 'errorfile'
      },
      'haproxy_fcgi' => {
        base_path: 'haproxy/settings', search_action: 'search_fcgis',
        crud_action: '%{action}_fcgi', wrapper: 'fcgi'
      },
      'haproxy_frontend' => {
        base_path: 'haproxy/settings', search_action: 'search_frontends',
        crud_action: '%{action}_frontend', wrapper: 'frontend'
      },
      'haproxy_group' => {
        base_path: 'haproxy/settings', search_action: 'search_groups',
        crud_action: '%{action}_group', wrapper: 'group'
      },
      'haproxy_healthcheck' => {
        base_path: 'haproxy/settings', search_action: 'search_healthchecks',
        crud_action: '%{action}_healthcheck', wrapper: 'healthcheck'
      },
      'haproxy_lua' => {
        base_path: 'haproxy/settings', search_action: 'search_luas',
        crud_action: '%{action}_lua', wrapper: 'lua'
      },
      'haproxy_mailer' => {
        base_path: 'haproxy/settings', search_action: 'searchmailers',
        crud_action: '%{action}mailer', wrapper: 'mailer'
      },
      'haproxy_mapfile' => {
        base_path: 'haproxy/settings', search_action: 'search_mapfiles',
        crud_action: '%{action}_mapfile', wrapper: 'mapfile'
      },
      'haproxy_resolver' => {
        base_path: 'haproxy/settings', search_action: 'searchresolvers',
        crud_action: '%{action}resolver', wrapper: 'resolver'
      },
      'haproxy_server' => {
        base_path: 'haproxy/settings', search_action: 'search_servers',
        crud_action: '%{action}_server', wrapper: 'server'
      },
      'haproxy_settings' => {
        base_path: 'haproxy/settings', search_action: 'get',
        crud_action: '%{action}', wrapper: 'haproxy',
        singleton: true, search_method: :get,
        response_dig: %w[general maintenance]
      },
      'haproxy_user' => {
        base_path: 'haproxy/settings', search_action: 'search_users',
        crud_action: '%{action}_user', wrapper: 'user'
      },
      # --- HA Sync ---
      'hasync' => {
        base_path: 'core/hasync', search_action: 'get',
        crud_action: '%{action}', wrapper: 'hasync',
        singleton: true, search_method: :get
      },
      # --- IPsec ---
      'ipsec_child' => {
        base_path: 'ipsec/connections', search_action: 'searchChild',
        crud_action: '%{action}Child', wrapper: 'child'
      },
      'ipsec_connection' => {
        base_path: 'ipsec/connections', search_action: 'searchConnection',
        crud_action: '%{action}Connection', wrapper: 'connection'
      },
      'ipsec_keypair' => {
        base_path: 'ipsec/key_pairs', search_action: 'search_item',
        crud_action: '%{action}_item', wrapper: 'keyPair'
      },
      'ipsec_local' => {
        base_path: 'ipsec/connections', search_action: 'searchLocal',
        crud_action: '%{action}Local', wrapper: 'local'
      },
      'ipsec_pool' => {
        base_path: 'ipsec/pools', search_action: 'search',
        crud_action: '%{action}', wrapper: 'pool'
      },
      'ipsec_presharedkey' => {
        base_path: 'ipsec/pre_shared_keys', search_action: 'search_item',
        crud_action: '%{action}_item', wrapper: 'preSharedKey'
      },
      'ipsec_remote' => {
        base_path: 'ipsec/connections', search_action: 'searchRemote',
        crud_action: '%{action}Remote', wrapper: 'remote'
      },
      'ipsec_settings' => {
        base_path: 'ipsec/settings', search_action: 'get',
        crud_action: '%{action}', wrapper: 'ipsec',
        singleton: true, search_method: :get,
        response_dig: %w[general charon]
      },
      'ipsec_vti' => {
        base_path: 'ipsec/vti', search_action: 'search',
        crud_action: '%{action}', wrapper: 'vti'
      },
      # --- Kea DHCP ---
      'kea_ctrl_agent' => {
        base_path: 'kea/ctrl_agent', search_action: 'get',
        crud_action: '%{action}', wrapper: 'ctrlagent',
        singleton: true, search_method: :get,
        response_dig: ['general']
      },
      'kea_dhcpv4' => {
        base_path: 'kea/dhcpv4', search_action: 'get',
        crud_action: '%{action}', wrapper: 'dhcpv4',
        singleton: true, search_method: :get,
        response_dig: %w[general lexpire ha]
      },
      'kea_dhcpv4_peer' => {
        base_path: 'kea/dhcpv4', search_action: 'searchPeer',
        crud_action: '%{action}Peer', wrapper: 'peer'
      },
      'kea_dhcpv4_reservation' => {
        base_path: 'kea/dhcpv4', search_action: 'searchReservation',
        crud_action: '%{action}Reservation', wrapper: 'reservation'
      },
      'kea_dhcpv4_subnet' => {
        base_path: 'kea/dhcpv4', search_action: 'searchSubnet',
        crud_action: '%{action}Subnet', wrapper: 'subnet4'
      },
      'kea_dhcpv6' => {
        base_path: 'kea/dhcpv6', search_action: 'get',
        crud_action: '%{action}', wrapper: 'dhcpv6',
        singleton: true, search_method: :get,
        response_dig: %w[general lexpire ha]
      },
      'kea_dhcpv6_pd_pool' => {
        base_path: 'kea/dhcpv6', search_action: 'searchPdPool',
        crud_action: '%{action}PdPool', wrapper: 'pd_pool'
      },
      'kea_dhcpv6_peer' => {
        base_path: 'kea/dhcpv6', search_action: 'searchPeer',
        crud_action: '%{action}Peer', wrapper: 'peer'
      },
      'kea_dhcpv6_reservation' => {
        base_path: 'kea/dhcpv6', search_action: 'searchReservation',
        crud_action: '%{action}Reservation', wrapper: 'reservation'
      },
      'kea_dhcpv6_subnet' => {
        base_path: 'kea/dhcpv6', search_action: 'searchSubnet',
        crud_action: '%{action}Subnet', wrapper: 'subnet6'
      },
      # --- Node Exporter ---
      'node_exporter' => {
        base_path: 'nodeexporter/general', search_action: 'get',
        crud_action: '%{action}', wrapper: 'general',
        singleton: true, search_method: :get
      },
      # --- OpenVPN ---
      'openvpn_cso' => {
        base_path: 'openvpn/client_overwrites', search_action: 'search',
        crud_action: '%{action}', wrapper: 'cso'
      },
      'openvpn_instance' => {
        base_path: 'openvpn/instances', search_action: 'search',
        crud_action: '%{action}', wrapper: 'instance'
      },
      'openvpn_statickey' => {
        base_path: 'openvpn/instances', search_action: 'search_static_key',
        crud_action: '%{action}_static_key', wrapper: 'statickey'
      },
      # --- Route ---
      'route' => {
        base_path: 'routes/routes', search_action: 'searchroute',
        crud_action: '%{action}route', wrapper: 'route'
      },
      # --- Snapshot ---
      'snapshot' => {
        base_path: 'core/snapshots', search_action: 'search',
        crud_action: '%{action}', wrapper: nil,
        search_method: :get
      },
      # --- Syslog ---
      'syslog' => {
        base_path: 'syslog/settings', search_action: 'search_destinations',
        crud_action: '%{action}_destination', wrapper: 'destination'
      },
      # --- Trust ---
      'trust_ca' => {
        base_path: 'trust/ca', search_action: 'search',
        crud_action: '%{action}', wrapper: 'ca'
      },
      'trust_cert' => {
        base_path: 'trust/cert', search_action: 'search',
        crud_action: '%{action}', wrapper: 'cert'
      },
      'trust_crl' => {
        base_path: 'trust/crl', search_action: 'search',
        crud_action: '%{action}', wrapper: 'crl',
        search_method: :get
      },
      # --- Tunable ---
      'tunable' => {
        base_path: 'core/tunables', search_action: 'search_item',
        crud_action: '%{action}_item', wrapper: 'sysctl'
      },
      # --- User ---
      'user' => {
        base_path: 'auth/user', search_action: 'search',
        crud_action: '%{action}', wrapper: 'user'
      },
      # --- Zabbix Agent ---
      'zabbix_agent' => {
        base_path: 'zabbixagent/settings', search_action: 'get',
        crud_action: '%{action}', wrapper: 'zabbixagent',
        singleton: true, search_method: :get,
        response_reject: %w[userparameters aliases]
      },
      'zabbix_agent_alias' => {
        base_path: 'zabbixagent/settings', search_action: 'get',
        crud_action: '%{action}Alias', wrapper: 'alias',
        search_method: :get
      },
      'zabbix_agent_userparameter' => {
        base_path: 'zabbixagent/settings', search_action: 'get',
        crud_action: '%{action}Userparameter', wrapper: 'userparameter',
        search_method: :get
      },
      # --- Zabbix Proxy ---
      'zabbix_proxy' => {
        base_path: 'zabbixproxy/general', search_action: 'get',
        crud_action: '%{action}', wrapper: 'general',
        singleton: true, search_method: :get
      },
    }.freeze

    class << self
      # Looks up a resource by name.
      #
      # @param name [String] Resource name (e.g. 'haproxy_server')
      # @return [Hash, nil] Resource definition or nil if not found
      def lookup(name)
        RESOURCES[name.to_s]
      end

      # Returns all registered resource names (sorted).
      #
      # @return [Array<String>]
      def names
        RESOURCES.keys.sort
      end

      # Builds a Resource instance from a registry entry.
      #
      # @param client [OpnApi::Client] API client
      # @param name [String] Resource name from registry
      # @return [OpnApi::Resource]
      # @raise [OpnApi::Error] if resource name not found
      def build(client, name)
        entry = lookup(name)
        raise OpnApi::Error, "Unknown resource type: '#{name}'. Run 'opn-api resources' for a list." unless entry

        OpnApi::Resource.new(
          client: client,
          base_path: entry[:base_path],
          search_action: entry[:search_action],
          crud_action: entry[:crud_action],
          singleton: entry[:singleton] || false,
          search_method: entry[:search_method] || :post,
        )
      end
    end
  end
end
