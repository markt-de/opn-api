# frozen_string_literal: true

require 'spec_helper'
require 'opn_api/cli/main'
require 'tempfile'

RSpec.describe OpnApi::CLI::Commands::Backup do
  let(:client) do
    instance_double(OpnApi::Client)
  end

  let(:opts) { { device: 'default', config_dir: '/tmp' } }
  let(:xml_data) { '<?xml version="1.0"?><opnsense><system><hostname>fw01</hostname></system></opnsense>' }

  before do
    allow(OpnApi::CLI::Commands::Base).to receive(:build_client).with(opts).and_return(client)
  end

  describe '.download' do
    it 'writes backup to file and returns status hash' do
      allow(client).to receive(:get).with('core/backup/download/this', raw: true).and_return(xml_data)

      Tempfile.create('backup') do |f|
        result = described_class.download([f.path], opts)

        expect(result).to eq({
          'status' => 'ok',
          'file' => f.path,
          'size' => xml_data.bytesize,
        })
        expect(File.read(f.path)).to eq(xml_data)
      end
    end

    it 'returns raw XML string without output path' do
      allow(client).to receive(:get).with('core/backup/download/this', raw: true).and_return(xml_data)

      result = described_class.download([], opts)
      expect(result).to eq(xml_data)
    end

    it 'raises on API error' do
      allow(client).to receive(:get).with('core/backup/download/this', raw: true)
                                    .and_raise(OpnApi::ApiError.new(
                                                 'API error 403',
                                                 code: 403,
                                                 body: 'Forbidden',
                                                 uri: 'https://fw.example.com/api/core/backup/download',
                                               ))

      expect { described_class.download([], opts) }.to raise_error(OpnApi::ApiError)
    end
  end
end
