# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OpnApi::Client do
  let(:client) do
    described_class.new(
      url: 'https://fw.example.com/api',
      api_key: 'testkey',
      api_secret: 'testsecret',
      ssl_verify: false,
      timeout: 30,
    )
  end

  describe '#get' do
    it 'performs a GET request and returns parsed JSON' do
      stub_request(:get, 'https://fw.example.com/api/firmware/info/running')
        .with(headers: { 'Accept' => 'application/json' })
        .to_return(status: 200, body: '{"product_version":"24.7"}')

      result = client.get('firmware/info/running')
      expect(result).to eq({ 'product_version' => '24.7' })
    end

    it 'raises ApiError on non-2xx response' do
      stub_request(:get, 'https://fw.example.com/api/bad/path')
        .to_return(status: 404, body: 'Not Found')

      expect { client.get('bad/path') }.to raise_error(OpnApi::ApiError) { |e|
        expect(e.code).to eq(404)
      }
    end

    it 'returns empty hash for empty response body' do
      stub_request(:get, 'https://fw.example.com/api/empty')
        .to_return(status: 200, body: '')

      expect(client.get('empty')).to eq({})
    end

    context 'with raw: true' do
      it 'returns raw response body as string' do
        xml_body = '<?xml version="1.0"?><opnsense><system/></opnsense>'
        stub_request(:get, 'https://fw.example.com/api/core/backup/download/this')
          .to_return(status: 200, body: xml_body)

        result = client.get('core/backup/download/this', raw: true)
        expect(result).to eq(xml_body)
      end

      it 'raises ApiError on non-2xx response' do
        stub_request(:get, 'https://fw.example.com/api/core/backup/download/this')
          .to_return(status: 403, body: 'Forbidden')

        expect { client.get('core/backup/download/this', raw: true) }
          .to raise_error(OpnApi::ApiError) { |e| expect(e.code).to eq(403) }
      end
    end
  end

  describe '#post' do
    it 'performs a POST request with JSON body' do
      stub_request(:post, 'https://fw.example.com/api/firewall/alias/search_item')
        .with(
          body: '{}',
          headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' },
        )
        .to_return(status: 200, body: '{"rows":[]}')

      result = client.post('firewall/alias/search_item', {})
      expect(result).to eq({ 'rows' => [] })
    end
  end

  describe 'redirect handling' do
    it 'follows 308 redirects preserving method and body' do
      stub_request(:post, 'http://fw.example.com/api/test')
        .to_return(status: 308, headers: { 'Location' => 'https://fw.example.com/api/test' })
      stub_request(:post, 'https://fw.example.com/api/test')
        .to_return(status: 200, body: '{"ok":true}')

      http_client = described_class.new(
        url: 'http://fw.example.com/api',
        api_key: 'k', api_secret: 's'
      )
      result = http_client.post('test', {})
      expect(result).to eq({ 'ok' => true })
    end

    it 'follows 302 redirects switching to GET' do
      stub_request(:post, 'https://fw.example.com/api/old')
        .to_return(status: 302, headers: { 'Location' => 'https://fw.example.com/api/new' })
      stub_request(:get, 'https://fw.example.com/api/new')
        .to_return(status: 200, body: '{"redirected":true}')

      result = client.post('old', {})
      expect(result).to eq({ 'redirected' => true })
    end

    it 'raises on too many redirects' do
      stub_request(:get, %r{fw\.example\.com})
        .to_return(status: 308, headers: { 'Location' => 'https://fw.example.com/api/loop' })

      expect { client.get('loop') }.to raise_error(OpnApi::ConnectionError, %r{redirects})
    end
  end

  describe 'error handling' do
    it 'raises ConnectionError on ECONNREFUSED' do
      stub_request(:get, 'https://fw.example.com/api/test')
        .to_raise(Errno::ECONNREFUSED)

      expect { client.get('test') }.to raise_error(OpnApi::ConnectionError)
    end

    it 'raises TimeoutError on Net::OpenTimeout' do
      stub_request(:get, 'https://fw.example.com/api/test')
        .to_raise(Net::OpenTimeout)

      expect { client.get('test') }.to raise_error(OpnApi::TimeoutError)
    end

    it 'raises ApiError on JSON parse failure' do
      stub_request(:get, 'https://fw.example.com/api/test')
        .to_return(status: 200, body: 'not json')

      expect { client.get('test') }.to raise_error(OpnApi::ApiError, %r{parse error})
    end
  end
end
