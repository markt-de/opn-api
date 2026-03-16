# frozen_string_literal: true

require 'json'
require 'yaml'

module OpnApi
  module CLI
    # Output formatter for CLI results. Supports table, JSON, and YAML output.
    #
    # Table output supports field filtering:
    # - Explicit fields via -F (e.g. -F uuid,name,type)
    # - Default: first 5 fields (to keep output readable)
    # - All fields via -A
    # JSON and YAML always output all data unmodified.
    module Formatter
      # Default number of columns shown in table output when no -F or -A is given.
      DEFAULT_MAX_FIELDS = 5

      module_function

      # Formats data according to the specified format.
      #
      # @param data [Object] Data to format (Hash, Array, String)
      # @param format [Symbol] Output format (:table, :json, :yaml)
      # @param fields [Array<String>, nil] Explicit field names for table output
      # @param all_fields [Boolean] Show all fields in table output
      # @param show_empty [Boolean] Show empty fields in table output (default: hidden)
      # @return [String] Formatted output
      def format(data, format: :table, fields: nil, all_fields: false, show_empty: false)
        case format
        when :json
          format_json(data)
        when :yaml
          format_yaml(data)
        else
          format_table(data, fields: fields, all_fields: all_fields, show_empty: show_empty)
        end
      end

      # Pretty-printed JSON output (always full data).
      def format_json(data)
        JSON.pretty_generate(data)
      end

      # YAML output (always full data).
      def format_yaml(data)
        data.to_yaml
      end

      # Human-readable table output with optional field filtering.
      def format_table(data, fields: nil, all_fields: false, show_empty: false)
        case data
        when Array
          format_array_table(data, fields: fields, all_fields: all_fields)
        when Hash
          format_hash_table(data, show_empty: show_empty)
        else
          data.to_s
        end
      end

      # Formats an array of hashes as a column-aligned table.
      # Applies field filtering for readability.
      def format_array_table(rows, fields: nil, all_fields: false)
        return '(no results)' if rows.empty?

        # Flatten nested values to strings for display
        flat_rows = rows.map do |row|
          row.transform_values { |v| v.is_a?(Hash) || v.is_a?(Array) ? JSON.generate(v) : v.to_s }
        end

        # Determine which columns to show
        all_keys = flat_rows.flat_map(&:keys).uniq
        display_keys = select_display_keys(all_keys, fields: fields, all_fields: all_fields)

        # Calculate column widths
        widths = display_keys.to_h do |k|
          [k, ([k.length] + flat_rows.map { |r| r.fetch(k, '').length }).max]
        end

        # Header line
        header = display_keys.map { |k| k.ljust(widths[k]) }.join('  ')
        separator = display_keys.map { |k| '-' * widths[k] }.join('  ')

        # Data lines
        lines = flat_rows.map do |row|
          display_keys.map { |k| row.fetch(k, '').ljust(widths[k]) }.join('  ')
        end

        # Add hint about hidden fields if any were truncated
        result = [header, separator, *lines].join("\n")
        hidden_count = all_keys.length - display_keys.length
        if hidden_count.positive?
          result += "\n\n(#{hidden_count} more field(s) hidden, use -A to show all or -F to select)"
        end
        result
      end

      # Formats a hash as key-value pairs with recursive indentation
      # for nested structures.
      #
      # @param hash [Hash] Hash to format
      # @param show_empty [Boolean] Include fields with empty string values
      def format_hash_table(hash, show_empty: false)
        return '(empty)' if hash.empty?

        format_hash_recursive(hash, 0, show_empty: show_empty)
      end

      # Recursively formats a hash with indentation for nested structures.
      #
      # @param hash [Hash] Hash to format
      # @param indent [Integer] Current indentation level
      # @param show_empty [Boolean] Include fields with empty string values
      # @return [String] Formatted output
      def format_hash_recursive(hash, indent, show_empty: false)
        prefix = '  ' * indent
        # Filter out empty string values unless show_empty is set
        display_hash = show_empty ? hash : hash.reject { |_k, v| v.is_a?(String) && v.empty? }
        return "#{prefix}(all fields empty)" if display_hash.empty?

        max_key = display_hash.keys.map { |k| k.to_s.length }.max

        display_hash.map do |k, v|
          label = "#{prefix}#{k.to_s.ljust(max_key)}"
          format_value_recursive(label, v, indent, show_empty: show_empty)
        end.join("\n")
      end

      # Formats a single value, recursing into hashes and arrays.
      #
      # @param label [String] Pre-formatted "key" label with padding
      # @param value [Object] Value to format
      # @param indent [Integer] Current indentation level
      # @param show_empty [Boolean] Include fields with empty string values
      # @return [String] Formatted line(s)
      def format_value_recursive(label, value, indent, show_empty: false)
        case value
        when Hash
          if value.empty?
            "#{label}  (empty)"
          else
            # Render nested hash on next lines with increased indent
            "#{label}:\n#{format_hash_recursive(value, indent + 1, show_empty: show_empty)}"
          end
        when Array
          if value.empty?
            "#{label}  (none)"
          else
            # Render array items on next lines with increased indent
            items = value.map { |item| format_array_item(item, indent + 1, show_empty: show_empty) }
            "#{label}:\n#{items.join("\n")}"
          end
        else
          "#{label}  #{value}"
        end
      end

      # Formats a single array item with indentation.
      #
      # @param item [Object] Array element
      # @param indent [Integer] Indentation level
      # @param show_empty [Boolean] Include fields with empty string values
      # @return [String] Formatted line(s)
      def format_array_item(item, indent, show_empty: false)
        prefix = '  ' * indent
        case item
        when Hash
          # Render hash items with "- " prefix for first line
          lines = format_hash_recursive(item, indent, show_empty: show_empty).split("\n")
          first = lines.first&.sub(%r{\A#{Regexp.escape(prefix)}}, "#{prefix}- ")
          rest = lines[1..]&.map { |l| "  #{l}" }
          [first, *rest].compact.join("\n")
        else
          "#{prefix}- #{item}"
        end
      end

      # Determines which keys to display based on filtering options.
      #
      # @param all_keys [Array<String>] All available column names
      # @param fields [Array<String>, nil] Explicit field selection
      # @param all_fields [Boolean] Show all fields
      # @return [Array<String>] Keys to display
      def select_display_keys(all_keys, fields: nil, all_fields: false)
        if fields
          # Explicit field selection: only show requested fields that exist
          fields.select { |f| all_keys.include?(f) }
        elsif all_fields || all_keys.length <= DEFAULT_MAX_FIELDS
          all_keys
        else
          # Default: show first N fields
          all_keys.first(DEFAULT_MAX_FIELDS)
        end
      end
    end
  end
end
