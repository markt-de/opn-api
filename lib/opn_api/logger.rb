# frozen_string_literal: true

module OpnApi
  # Pluggable logger with five severity levels.
  #
  # Default: writes to $stderr at :info level. For puppet-opn integration,
  # replace with a logger that delegates to Puppet.debug/notice/warning/err.
  #
  # @example Custom logger for Puppet integration
  #   OpnApi.logger = PuppetLogger.new
  class Logger
    LEVELS = %i[debug info notice warning error].freeze

    # @param output [IO] Output stream (default: $stderr)
    # @param level [Symbol] Minimum severity to log (default: :info)
    def initialize(output: $stderr, level: :info)
      @output = output
      @level  = LEVELS.index(level) || 1
    end

    LEVELS.each_with_index do |name, idx|
      define_method(name) do |msg|
        return if idx < @level

        @output.puts("[opn_api] #{name.upcase}: #{msg}")
      end
    end
  end
end
