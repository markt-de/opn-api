# frozen_string_literal: true

require 'spec_helper'
require 'opn_api/cli/formatter'

RSpec.describe OpnApi::CLI::Formatter do
  describe '.format_table' do
    context 'with a flat hash' do
      it 'renders key-value pairs' do
        result = described_class.format_table({ 'name' => 'test', 'enabled' => '1' })
        expect(result).to include('name     test')
        expect(result).to include('enabled  1')
      end
    end

    context 'with nested hashes' do
      it 'renders nested structure with indentation' do
        data = {
          'settings' => {
            'enabled' => '1',
            'port' => '8080',
          },
          'name' => 'test',
        }
        result = described_class.format_table(data)
        # Top-level keys
        expect(result).to include("settings:\n")
        expect(result).to include('name      test')
        # Nested keys are indented
        expect(result).to include('  enabled  1')
        expect(result).to include('  port     8080')
      end
    end

    context 'with deeply nested hashes' do
      it 'renders multiple levels of indentation' do
        data = {
          'general' => {
            'tuning' => {
              'maxconn' => '2000',
            },
          },
        }
        result = described_class.format_table(data)
        expect(result).to include("general:\n")
        expect(result).to include("  tuning:\n")
        expect(result).to include('    maxconn  2000')
      end
    end

    context 'with empty nested hash' do
      it 'renders (empty) marker' do
        data = { 'settings' => {} }
        result = described_class.format_table(data)
        expect(result).to include('settings  (empty)')
      end
    end

    context 'with nested arrays' do
      it 'renders array items with dash prefix' do
        data = { 'items' => %w[one two three] }
        result = described_class.format_table(data)
        expect(result).to include("items:\n")
        expect(result).to include('  - one')
        expect(result).to include('  - two')
        expect(result).to include('  - three')
      end
    end

    context 'with array of hashes' do
      it 'renders each hash item with dash and indentation' do
        data = {
          'servers' => [
            { 'name' => 'web01', 'port' => '80' },
            { 'name' => 'web02', 'port' => '443' },
          ],
        }
        result = described_class.format_table(data)
        expect(result).to include("servers:\n")
        expect(result).to include('  - name  web01')
        expect(result).to include('  - name  web02')
      end
    end

    context 'with empty array' do
      it 'renders (none) marker' do
        data = { 'items' => [] }
        result = described_class.format_table(data)
        expect(result).to include('items  (none)')
      end
    end

    context 'with empty string values' do
      it 'hides empty fields by default' do
        data = { 'name' => 'test', 'description' => '', 'email' => '', 'enabled' => '1' }
        result = described_class.format_table(data)
        expect(result).to include('name     test')
        expect(result).to include('enabled  1')
        expect(result).not_to include('description')
        expect(result).not_to include('email')
      end

      it 'shows empty fields with show_empty option' do
        data = { 'name' => 'test', 'description' => '', 'enabled' => '1' }
        result = described_class.format_table(data, show_empty: true)
        expect(result).to include('name         test')
        expect(result).to include('description')
        expect(result).to include('enabled      1')
      end

      it 'hides empty fields in nested hashes' do
        data = {
          'account' => {
            'name' => 'test',
            'email' => '',
            'ca' => 'letsencrypt',
          },
        }
        result = described_class.format_table(data)
        expect(result).to include('  name  test')
        expect(result).to include('  ca    letsencrypt')
        expect(result).not_to include('email')
      end

      it 'shows (all fields empty) when all fields are empty strings' do
        data = { 'section' => { 'a' => '', 'b' => '' } }
        result = described_class.format_table(data)
        expect(result).to include('(all fields empty)')
      end
    end

    context 'with empty hash' do
      it 'returns (empty)' do
        expect(described_class.format_table({})).to eq('(empty)')
      end
    end

    context 'with array of flat hashes (search results)' do
      it 'renders column-aligned table' do
        rows = [
          { 'uuid' => '123', 'name' => 'test' },
          { 'uuid' => '456', 'name' => 'other' },
        ]
        result = described_class.format_table(rows)
        expect(result).to include('uuid')
        expect(result).to include('name')
        expect(result).to include('123')
        expect(result).to include('test')
      end
    end
  end

  describe '.format_json' do
    it 'returns pretty JSON' do
      data = { 'key' => 'value' }
      result = described_class.format_json(data)
      expect(result).to eq("{\n  \"key\": \"value\"\n}")
    end
  end

  describe '.format_yaml' do
    it 'returns YAML' do
      data = { 'key' => 'value' }
      result = described_class.format_yaml(data)
      expect(result).to include('key: value')
    end
  end
end
