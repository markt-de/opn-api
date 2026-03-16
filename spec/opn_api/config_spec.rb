# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe OpnApi::Config do
  let(:tmpdir) { Dir.mktmpdir('opn-api-test') }
  let(:device_yaml) do
    <<~YAML
      url: https://192.168.1.1/api
      api_key: +testkey
      api_secret: +testsecret
      ssl_verify: false
      timeout: 30
    YAML
  end

  after { FileUtils.rm_rf(tmpdir) }

  before do
    File.write(File.join(tmpdir, 'myfw.yaml'), device_yaml)
  end

  describe '#device_names' do
    it 'returns available device names' do
      config = described_class.new(config_dir: tmpdir)
      expect(config.device_names).to eq(['myfw'])
    end

    it 'returns sorted names' do
      File.write(File.join(tmpdir, 'afw.yaml'), device_yaml)
      File.write(File.join(tmpdir, 'zfw.yaml'), device_yaml)
      config = described_class.new(config_dir: tmpdir)
      expect(config.device_names).to eq(%w[afw myfw zfw])
    end

    it 'returns empty array for missing directory' do
      config = described_class.new(config_dir: '/nonexistent')
      expect(config.device_names).to eq([])
    end
  end

  describe '#device' do
    it 'returns device configuration hash' do
      config = described_class.new(config_dir: tmpdir)
      result = config.device('myfw')
      expect(result).to include(
        'url' => 'https://192.168.1.1/api',
        'api_key' => '+testkey',
        'ssl_verify' => false,
        'timeout' => 30,
      )
    end

    it 'raises ConfigError for missing device' do
      config = described_class.new(config_dir: tmpdir)
      expect { config.device('missing') }.to raise_error(OpnApi::ConfigError, %r{not found})
    end

    it 'raises ConfigError for malformed YAML' do
      File.write(File.join(tmpdir, 'bad.yaml'), '- just a list')
      config = described_class.new(config_dir: tmpdir)
      expect { config.device('bad') }.to raise_error(OpnApi::ConfigError, %r{not a valid YAML hash})
    end
  end

  describe '#client_for' do
    it 'returns a Client instance' do
      config = described_class.new(config_dir: tmpdir)
      client = config.client_for('myfw')
      expect(client).to be_a(OpnApi::Client)
    end
  end

  describe 'OPN_API_CONFIG_DIR environment variable' do
    it 'overrides explicit config_dir' do
      env_dir = Dir.mktmpdir('opn-api-env')
      File.write(File.join(env_dir, 'envfw.yaml'), device_yaml)

      begin
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('OPN_API_CONFIG_DIR', nil).and_return(env_dir)

        config = described_class.new(config_dir: tmpdir)
        expect(config.device_names).to include('envfw')
      ensure
        FileUtils.rm_rf(env_dir)
      end
    end
  end
end
