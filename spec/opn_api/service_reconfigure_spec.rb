# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OpnApi::ServiceReconfigure do
  let(:client) { instance_double(OpnApi::Client) }

  describe '.register and .[]' do
    it 'registers and retrieves a group' do
      described_class.register(:test_group,
                               endpoint: 'test/service/reconfigure',
                               log_prefix: 'test')

      group = described_class[:test_group]
      expect(group).to be_a(described_class)
      expect(group.name).to eq(:test_group)
    end

    it 'raises Error for unknown group' do
      expect do
        described_class[:nonexistent_group_xyz]
      end.to raise_error(OpnApi::Error, %r{unknown group})
    end

    it 'is idempotent' do
      g1 = described_class.register(:idem_test,
                                    endpoint: 'test/reconfigure',
                                    log_prefix: 'test')
      g2 = described_class.register(:idem_test,
                                    endpoint: 'different/path',
                                    log_prefix: 'different')
      expect(g1).to equal(g2)
    end
  end

  describe '.load_defaults!' do
    it 'registers all default OPNsense groups' do
      described_class.load_defaults!
      names = described_class.registered_names
      expect(names).to include(:haproxy, :ipsec, :openvpn, :kea, :firewall_alias,
                               :firewall_rule, :cron, :dhcrelay, :gateway,
                               :puppet_agent, :route)
    end
  end

  describe '#mark and #run' do
    before do
      described_class.register(:run_test,
                               endpoint: 'test/service/reconfigure',
                               log_prefix: 'test')
    end

    it 'reconfigures marked devices and returns results' do
      allow(client).to receive(:post)
        .with('test/service/reconfigure', {})
        .and_return({ 'status' => 'ok' })

      group = described_class[:run_test]
      group.mark('opnsense01', client)
      results = group.run

      expect(results).to eq({ 'opnsense01' => :ok })
    end

    it 'skips devices with errors' do
      group = described_class[:run_test]
      group.mark('opnsense01', client)
      group.mark_error('opnsense01')
      results = group.run

      expect(results).to eq({ 'opnsense01' => :skipped })
    end

    it 'clears state after run' do
      allow(client).to receive(:post).and_return({ 'status' => 'ok' })

      group = described_class[:run_test]
      group.mark('opnsense01', client)
      group.run

      # Second run should be empty
      results = group.run
      expect(results).to eq({})
    end
  end

  describe 'configtest support' do
    before do
      described_class.register(:configtest_test,
                               endpoint: 'haproxy/service/reconfigure',
                               log_prefix: 'test',
                               configtest_endpoint: 'haproxy/service/configtest')
    end

    it 'skips reconfigure on ALERT' do
      allow(client).to receive(:get)
        .with('haproxy/service/configtest')
        .and_return({ 'result' => '[ALERT] config error' })

      group = described_class[:configtest_test]
      group.mark('opnsense01', client)
      results = group.run

      expect(results).to eq({ 'opnsense01' => :skipped })
    end

    it 'proceeds on passing configtest' do
      allow(client).to receive(:get)
        .with('haproxy/service/configtest')
        .and_return({ 'result' => 'Configuration file is valid' })
      allow(client).to receive(:post)
        .with('haproxy/service/reconfigure', {})
        .and_return({ 'status' => 'ok' })

      group = described_class[:configtest_test]
      group.mark('opnsense01', client)
      results = group.run

      expect(results).to eq({ 'opnsense01' => :ok })
    end

    it 'proceeds with warning on WARNING' do
      allow(client).to receive(:get)
        .with('haproxy/service/configtest')
        .and_return({ 'result' => '[WARNING] minor issue' })
      allow(client).to receive(:post)
        .with('haproxy/service/reconfigure', {})
        .and_return({ 'status' => 'ok' })

      group = described_class[:configtest_test]
      group.mark('opnsense01', client)
      results = group.run

      expect(results).to eq({ 'opnsense01' => :ok })
    end
  end
end
