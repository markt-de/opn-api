# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OpnApi::IdResolver do
  let(:client) do
    instance_double(OpnApi::Client)
  end

  let(:search_response) do
    {
      'rows' => [
        { 'uuid' => 'aaa-111', 'name' => 'server1' },
        { 'uuid' => 'bbb-222', 'name' => 'server2' },
      ],
    }
  end

  describe '.translate_to_names' do
    it 'translates UUIDs to names' do
      allow(client).to receive(:post).with('haproxy/settings/search_servers', {})
                                     .and_return(search_response)

      config = { 'linkedServers' => 'aaa-111,bbb-222' }
      relation_fields = {
        'linkedServers' => { endpoint: 'haproxy/settings/search_servers', multiple: true },
      }

      result = described_class.translate_to_names(client, 'myfw', relation_fields, config)
      expect(result['linkedServers']).to eq('server1,server2')
    end

    it 'preserves unknown IDs' do
      allow(client).to receive(:post).and_return(search_response)

      config = { 'linkedServers' => 'aaa-111,unknown-uuid' }
      relation_fields = {
        'linkedServers' => { endpoint: 'haproxy/settings/search_servers', multiple: true },
      }

      result = described_class.translate_to_names(client, 'myfw', relation_fields, config)
      expect(result['linkedServers']).to eq('server1,unknown-uuid')
    end

    it 'handles single-value fields' do
      allow(client).to receive(:post).and_return(search_response)

      config = { 'defaultBackend' => 'aaa-111' }
      relation_fields = {
        'defaultBackend' => { endpoint: 'haproxy/settings/search_servers', multiple: false },
      }

      result = described_class.translate_to_names(client, 'myfw', relation_fields, config)
      expect(result['defaultBackend']).to eq('server1')
    end

    it 'does not modify the original config' do
      allow(client).to receive(:post).and_return(search_response)

      config = { 'linkedServers' => 'aaa-111' }
      relation_fields = {
        'linkedServers' => { endpoint: 'haproxy/settings/search_servers', multiple: false },
      }

      described_class.translate_to_names(client, 'myfw', relation_fields, config)
      expect(config['linkedServers']).to eq('aaa-111')
    end
  end

  describe '.translate_to_uuids' do
    it 'translates names to UUIDs' do
      allow(client).to receive(:post).with('haproxy/settings/search_servers', {})
                                     .and_return(search_response)

      config = { 'linkedServers' => 'server1,server2' }
      relation_fields = {
        'linkedServers' => { endpoint: 'haproxy/settings/search_servers', multiple: true },
      }

      result = described_class.translate_to_uuids(client, 'myfw', relation_fields, config)
      expect(result['linkedServers']).to eq('aaa-111,bbb-222')
    end

    it 'passes through existing UUIDs' do
      allow(client).to receive(:post).and_return(search_response)

      config = { 'linkedServers' => 'aaa-111' }
      relation_fields = {
        'linkedServers' => { endpoint: 'haproxy/settings/search_servers', multiple: false },
      }

      result = described_class.translate_to_uuids(client, 'myfw', relation_fields, config)
      expect(result['linkedServers']).to eq('aaa-111')
    end

    it 'raises ResolveError for unknown names' do
      allow(client).to receive(:post).and_return(search_response)

      config = { 'defaultBackend' => 'nonexistent' }
      relation_fields = {
        'defaultBackend' => { endpoint: 'haproxy/settings/search_servers', multiple: false },
      }

      expect do
        described_class.translate_to_uuids(client, 'myfw', relation_fields, config)
      end.to raise_error(OpnApi::ResolveError, %r{cannot resolve 'nonexistent'})
    end
  end

  describe '.dig_path' do
    it 'handles simple field names' do
      hash = { 'name' => 'test' }
      parent, key = described_class.dig_path(hash, 'name')
      expect(parent).to eq(hash)
      expect(key).to eq('name')
    end

    it 'handles dotted field paths' do
      hash = { 'general' => { 'stats' => { 'allowedUsers' => 'admin' } } }
      parent, key = described_class.dig_path(hash, 'general.stats.allowedUsers')
      expect(parent).to eq({ 'allowedUsers' => 'admin' })
      expect(key).to eq('allowedUsers')
    end

    it 'returns nil for missing intermediate keys' do
      hash = { 'general' => 'flat' }
      parent, key = described_class.dig_path(hash, 'general.stats.field')
      expect(parent).to be_nil
      expect(key).to be_nil
    end
  end

  describe '.deep_dup' do
    it 'creates independent copies of nested structures' do
      original = { 'a' => { 'b' => [1, 2, 3] } }
      copy = described_class.deep_dup(original)

      copy['a']['b'] << 4
      expect(original['a']['b']).to eq([1, 2, 3])
    end
  end

  describe 'caching' do
    it 'caches populate results across calls' do
      allow(client).to receive(:post).and_return(search_response).once

      relation_fields = {
        'field1' => { endpoint: 'haproxy/settings/search_servers', multiple: false },
      }

      described_class.translate_to_names(client, 'myfw', relation_fields, { 'field1' => 'aaa-111' })
      described_class.translate_to_names(client, 'myfw', relation_fields, { 'field1' => 'bbb-222' })

      expect(client).to have_received(:post).once
    end
  end
end
