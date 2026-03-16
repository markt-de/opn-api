# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OpnApi::Resource do
  let(:client) { instance_double(OpnApi::Client) }

  describe 'legacy mode (module/controller/type)' do
    let(:resource) do
      described_class.new(
        client: client,
        module_name: 'firewall',
        controller: 'alias',
        resource_type: 'item',
      )
    end

    describe '#search' do
      it 'sends POST to search endpoint and returns rows' do
        allow(client).to receive(:post)
          .with('firewall/alias/search_item', {})
          .and_return({ 'rows' => [{ 'uuid' => '123', 'name' => 'test' }] })

        results = resource.search
        expect(results).to eq([{ 'uuid' => '123', 'name' => 'test' }])
      end

      it 'returns empty array when no rows' do
        allow(client).to receive(:post)
          .with('firewall/alias/search_item', {})
          .and_return({})

        expect(resource.search).to eq([])
      end
    end

    describe '#get' do
      it 'sends GET to get endpoint with UUID' do
        allow(client).to receive(:get)
          .with('firewall/alias/get_item/abc-123')
          .and_return({ 'item' => { 'name' => 'test' } })

        result = resource.get('abc-123')
        expect(result['item']['name']).to eq('test')
      end
    end

    describe '#add' do
      it 'sends POST to add endpoint' do
        config = { 'item' => { 'name' => 'new', 'type' => 'host' } }
        allow(client).to receive(:post)
          .with('firewall/alias/add_item', config)
          .and_return({ 'result' => 'saved', 'uuid' => 'new-uuid' })

        result = resource.add(config)
        expect(result['uuid']).to eq('new-uuid')
      end
    end

    describe '#set' do
      it 'sends POST to set endpoint with UUID' do
        config = { 'item' => { 'name' => 'updated' } }
        allow(client).to receive(:post)
          .with('firewall/alias/set_item/abc-123', config)
          .and_return({ 'result' => 'saved' })

        result = resource.set('abc-123', config)
        expect(result['result']).to eq('saved')
      end
    end

    describe '#del' do
      it 'sends POST to del endpoint with UUID' do
        allow(client).to receive(:post)
          .with('firewall/alias/del_item/abc-123', {})
          .and_return({ 'result' => 'deleted' })

        result = resource.del('abc-123')
        expect(result['result']).to eq('deleted')
      end
    end
  end

  describe 'explicit path mode (base_path/search_action/crud_action)' do
    let(:resource) do
      described_class.new(
        client: client,
        base_path: 'haproxy/settings',
        search_action: 'search_servers',
        crud_action: '%{action}_server',
      )
    end

    it 'uses explicit search action' do
      allow(client).to receive(:post)
        .with('haproxy/settings/search_servers', {})
        .and_return({ 'rows' => [{ 'name' => 'web01' }] })

      results = resource.search
      expect(results).to eq([{ 'name' => 'web01' }])
    end

    it 'uses crud_action template for get' do
      allow(client).to receive(:get)
        .with('haproxy/settings/get_server/abc-123')
        .and_return({ 'server' => { 'name' => 'web01' } })

      result = resource.get('abc-123')
      expect(result['server']['name']).to eq('web01')
    end

    it 'uses crud_action template for add' do
      config = { 'server' => { 'name' => 'web02' } }
      allow(client).to receive(:post)
        .with('haproxy/settings/add_server', config)
        .and_return({ 'result' => 'saved', 'uuid' => 'new-uuid' })

      result = resource.add(config)
      expect(result['uuid']).to eq('new-uuid')
    end
  end

  describe 'camelCase endpoint (via explicit paths)' do
    let(:resource) do
      described_class.new(
        client: client,
        base_path: 'ipsec/connections',
        search_action: 'searchConnection',
        crud_action: '%{action}Connection',
      )
    end

    it 'uses camelCase action names' do
      allow(client).to receive(:post)
        .with('ipsec/connections/searchConnection', {})
        .and_return({ 'rows' => [] })

      resource.search
      expect(client).to have_received(:post).with('ipsec/connections/searchConnection', {})
    end

    it 'uses camelCase for get' do
      allow(client).to receive(:get)
        .with('ipsec/connections/getConnection/abc-123')
        .and_return({ 'connection' => {} })

      resource.get('abc-123')
      expect(client).to have_received(:get).with('ipsec/connections/getConnection/abc-123')
    end
  end

  describe 'bare endpoint (no suffix)' do
    let(:resource) do
      described_class.new(
        client: client,
        base_path: 'openvpn/instances',
        search_action: 'search',
        crud_action: '%{action}',
      )
    end

    it 'uses bare action names' do
      allow(client).to receive(:post)
        .with('openvpn/instances/search', {})
        .and_return({ 'rows' => [] })

      resource.search
      expect(client).to have_received(:post).with('openvpn/instances/search', {})
    end

    it 'uses bare get path' do
      allow(client).to receive(:get)
        .with('openvpn/instances/get/abc-123')
        .and_return({ 'instance' => {} })

      resource.get('abc-123')
      expect(client).to have_received(:get).with('openvpn/instances/get/abc-123')
    end
  end

  describe 'singleton resource' do
    let(:resource) do
      described_class.new(
        client: client,
        base_path: 'zabbixagent/settings',
        search_action: 'get',
        crud_action: '%{action}',
        singleton: true,
        search_method: :get,
      )
    end

    it 'uses GET for search' do
      allow(client).to receive(:get)
        .with('zabbixagent/settings/get')
        .and_return({ 'zabbixagent' => { 'settings' => {} } })

      result = resource.search
      expect(result).to eq({ 'zabbixagent' => { 'settings' => {} } })
    end

    it 'uses GET for show_settings (no UUID)' do
      allow(client).to receive(:get)
        .with('zabbixagent/settings/get')
        .and_return({ 'zabbixagent' => { 'settings' => {} } })

      resource.show_settings
      expect(client).to have_received(:get).with('zabbixagent/settings/get')
    end

    it 'uses POST for update_settings (no UUID)' do
      config = { 'zabbixagent' => { 'settings' => { 'main' => { 'enabled' => '1' } } } }
      allow(client).to receive(:post)
        .with('zabbixagent/settings/set', config)
        .and_return({ 'result' => 'saved' })

      result = resource.update_settings(config)
      expect(result['result']).to eq('saved')
    end

    it 'reports singleton flag' do
      expect(resource.singleton).to be true
    end
  end

  describe 'GET-based search (non-singleton)' do
    let(:resource) do
      described_class.new(
        client: client,
        base_path: 'core/snapshots',
        search_action: 'search',
        crud_action: '%{action}',
        search_method: :get,
      )
    end

    it 'uses GET for search and returns rows' do
      allow(client).to receive(:get)
        .with('core/snapshots/search')
        .and_return({ 'rows' => [{ 'name' => 'snap1' }] })

      results = resource.search
      expect(results).to eq([{ 'name' => 'snap1' }])
    end
  end
end
