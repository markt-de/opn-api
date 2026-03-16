# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OpnApi::Normalize do
  describe '.normalize_config' do
    it 'collapses selection hashes to comma-separated strings' do
      input = {
        'proto' => {
          'TCP' => { 'value' => 'TCP', 'selected' => 1 },
          'UDP' => { 'value' => 'UDP', 'selected' => 0 },
          'ICMP' => { 'value' => 'ICMP', 'selected' => 1 },
        },
      }
      result = described_class.normalize_config(input)
      expect(result['proto']).to eq('TCP,ICMP')
    end

    it 'recurses into nested hashes' do
      input = {
        'general' => {
          'mode' => {
            'http' => { 'value' => 'HTTP', 'selected' => 1 },
            'tcp' => { 'value' => 'TCP', 'selected' => 0 },
          },
          'description' => 'test',
        },
      }
      result = described_class.normalize_config(input)
      expect(result['general']['mode']).to eq('http')
      expect(result['general']['description']).to eq('test')
    end

    it 'passes non-hash values through unchanged' do
      expect(described_class.normalize_config('hello')).to eq('hello')
      expect(described_class.normalize_config(42)).to eq(42)
      expect(described_class.normalize_config(nil)).to be_nil
    end

    it 'passes regular hashes through unchanged' do
      input = { 'name' => 'test', 'enabled' => '1' }
      expect(described_class.normalize_config(input)).to eq(input)
    end

    it 'returns empty string for all-unselected selection hashes' do
      input = {
        'opt1' => { 'value' => 'A', 'selected' => 0 },
        'opt2' => { 'value' => 'B', 'selected' => 0 },
      }
      expect(described_class.normalize_config(input)).to eq('')
    end
  end

  describe '.selection_hash?' do
    it 'returns true for valid selection hashes' do
      hash = { 'a' => { 'value' => 'A', 'selected' => 1 } }
      expect(described_class.selection_hash?(hash)).to be true
    end

    it 'returns false for empty hashes' do
      expect(described_class.selection_hash?({})).to be false
    end

    it 'returns false for regular hashes' do
      expect(described_class.selection_hash?({ 'name' => 'test' })).to be false
    end
  end
end
