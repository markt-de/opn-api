# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OpnApi::ResourceRegistry do
  describe '.lookup' do
    it 'returns entry for known resource' do
      entry = described_class.lookup('haproxy_server')
      expect(entry[:base_path]).to eq('haproxy/settings')
      expect(entry[:search_action]).to eq('search_servers')
      expect(entry[:crud_action]).to eq('%{action}_server')
      expect(entry[:wrapper]).to eq('server')
    end

    it 'returns nil for unknown resource' do
      expect(described_class.lookup('nonexistent')).to be_nil
    end

    it 'handles IPsec camelCase endpoints' do
      entry = described_class.lookup('ipsec_connection')
      expect(entry[:base_path]).to eq('ipsec/connections')
      expect(entry[:search_action]).to eq('searchConnection')
      expect(entry[:crud_action]).to eq('%{action}Connection')
      expect(entry[:wrapper]).to eq('connection')
    end

    it 'handles bare endpoints (OpenVPN)' do
      entry = described_class.lookup('openvpn_instance')
      expect(entry[:base_path]).to eq('openvpn/instances')
      expect(entry[:search_action]).to eq('search')
      expect(entry[:crud_action]).to eq('%{action}')
      expect(entry[:wrapper]).to eq('instance')
    end

    it 'handles tunable with mismatched wrapper key' do
      entry = described_class.lookup('tunable')
      expect(entry[:base_path]).to eq('core/tunables')
      expect(entry[:wrapper]).to eq('sysctl')
    end

    it 'handles singleton resources' do
      entry = described_class.lookup('haproxy_settings')
      expect(entry[:base_path]).to eq('haproxy/settings')
      expect(entry[:singleton]).to be true
      expect(entry[:search_method]).to eq(:get)
      expect(entry[:wrapper]).to eq('haproxy')
      expect(entry[:response_dig]).to eq(%w[general maintenance])
    end

    it 'provides response_dig for singletons with sub-resources' do
      # Single sub-key extraction (acmeclient settings nested under 'settings')
      expect(described_class.lookup('acmeclient_settings')[:response_dig]).to eq(['settings'])
      # Multi-key slice (haproxy, ipsec, kea)
      expect(described_class.lookup('ipsec_settings')[:response_dig]).to eq(%w[general charon])
      expect(described_class.lookup('kea_dhcpv4')[:response_dig]).to eq(%w[general lexpire ha])
      expect(described_class.lookup('kea_dhcpv6')[:response_dig]).to eq(%w[general lexpire ha])
      expect(described_class.lookup('kea_ctrl_agent')[:response_dig]).to eq(['general'])
    end

    it 'provides response_reject for zabbix_agent' do
      entry = described_class.lookup('zabbix_agent')
      expect(entry[:response_reject]).to eq(%w[userparameters aliases])
    end

    it 'has no response filter for simple singletons' do
      # hasync, node_exporter, zabbix_proxy have no sub-resources in their response
      expect(described_class.lookup('hasync')[:response_dig]).to be_nil
      expect(described_class.lookup('node_exporter')[:response_dig]).to be_nil
      expect(described_class.lookup('zabbix_proxy')[:response_dig]).to be_nil
    end

    it 'handles Kea camelCase endpoints' do
      entry = described_class.lookup('kea_dhcpv4_subnet')
      expect(entry[:base_path]).to eq('kea/dhcpv4')
      expect(entry[:search_action]).to eq('searchSubnet')
      expect(entry[:crud_action]).to eq('%{action}Subnet')
      expect(entry[:wrapper]).to eq('subnet4')
    end

    it 'handles Zabbix agent sub-resources' do
      entry = described_class.lookup('zabbix_agent_alias')
      expect(entry[:base_path]).to eq('zabbixagent/settings')
      expect(entry[:crud_action]).to eq('%{action}Alias')
      expect(entry[:wrapper]).to eq('alias')
    end

    it 'uses puppet-opn naming conventions' do
      # opn_cron → 'cron' (not 'cron_job')
      expect(described_class.lookup('cron')).not_to be_nil
      # opn_syslog → 'syslog' (not 'syslog_destination')
      expect(described_class.lookup('syslog')).not_to be_nil
      # opn_group → 'group' (not 'user_group')
      expect(described_class.lookup('group')).not_to be_nil
      # opn_dhcrelay → 'dhcrelay' (not 'dhcrelay_relay')
      expect(described_class.lookup('dhcrelay')).not_to be_nil
    end
  end

  describe '.names' do
    it 'returns sorted list of resource names' do
      names = described_class.names
      expect(names).to eq(names.sort)
      expect(names).to include('haproxy_server', 'firewall_alias', 'ipsec_connection')
    end

    it 'includes all puppet-opn resource types' do
      names = described_class.names
      # Verify some from each category
      expect(names).to include(
        'acmeclient_account', 'acmeclient_settings',
        'cron', 'dhcrelay', 'dhcrelay_destination',
        'firewall_alias', 'firewall_rule',
        'gateway', 'group',
        'haproxy_server', 'haproxy_settings',
        'hasync',
        'ipsec_connection', 'ipsec_settings',
        'kea_ctrl_agent', 'kea_dhcpv4', 'kea_dhcpv4_subnet',
        'kea_dhcpv6', 'kea_dhcpv6_pd_pool',
        'node_exporter',
        'openvpn_instance', 'openvpn_cso', 'openvpn_statickey',
        'route', 'snapshot', 'syslog',
        'trust_ca', 'trust_cert', 'trust_crl',
        'tunable', 'user',
        'zabbix_agent', 'zabbix_agent_alias', 'zabbix_agent_userparameter',
        'zabbix_proxy'
      )
    end
  end

  describe '.build' do
    let(:client) { instance_double(OpnApi::Client) }

    it 'builds a Resource for known CRUD types' do
      resource = described_class.build(client, 'haproxy_server')
      expect(resource).to be_a(OpnApi::Resource)
      expect(resource.singleton).to be false
    end

    it 'builds a Resource for singleton types' do
      resource = described_class.build(client, 'haproxy_settings')
      expect(resource).to be_a(OpnApi::Resource)
      expect(resource.singleton).to be true
    end

    it 'raises for unknown types' do
      expect { described_class.build(client, 'nonexistent') }
        .to raise_error(OpnApi::Error, %r{Unknown resource type})
    end
  end
end
