# frozen_string_literal: true

module OpnApi
  # Normalization of OPNsense selection hashes.
  #
  # OPNsense returns multi-select/dropdown fields as hashes like:
  #   { "opt1" => { "value" => "Option 1", "selected" => 1 },
  #     "opt2" => { "value" => "Option 2", "selected" => 0 } }
  #
  # This module collapses them to comma-separated strings of selected
  # keys (e.g. "opt1") and recurses into nested hashes.
  module Normalize
    module_function

    # Recursively normalizes OPNsense selection hashes to simple values.
    #
    # @param obj [Object] The value to normalize
    # @return [Object] Normalized value
    def normalize_config(obj)
      return obj unless obj.is_a?(Hash)
      return normalize_selection(obj) if selection_hash?(obj)

      obj.transform_values { |v| normalize_config(v) }
    end

    # Detects whether a hash is an OPNsense selection hash.
    #
    # A selection hash has non-empty entries where every value is a Hash
    # containing at least 'value' and 'selected' keys.
    #
    # @param hash [Hash]
    # @return [Boolean]
    def selection_hash?(hash)
      hash.is_a?(Hash) &&
        !hash.empty? &&
        hash.values.all? { |v| v.is_a?(Hash) && v.key?('value') && v.key?('selected') }
    end

    # Collapses a selection hash to a comma-separated string of selected keys.
    #
    # @param hash [Hash] A selection hash (as detected by selection_hash?)
    # @return [String] Comma-separated selected keys
    def normalize_selection(hash)
      hash.select { |_k, v| v['selected'].to_i == 1 }.keys.join(',')
    end
  end
end
