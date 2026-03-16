# frozen_string_literal: true

module OpnApi
  # Base error class for all opn_api exceptions.
  class Error < StandardError; end

  # Raised when a network connection cannot be established
  # (e.g. ECONNREFUSED, EHOSTUNREACH, ETIMEDOUT).
  class ConnectionError < Error; end

  # Raised when an HTTP request times out (open_timeout or read_timeout).
  class TimeoutError < Error; end

  # Raised when the OPNsense API returns a non-2xx HTTP response.
  class ApiError < Error
    # @return [Integer] HTTP status code
    attr_reader :code

    # @return [String] HTTP response body
    attr_reader :body

    # @return [String] Request URI that caused the error
    attr_reader :uri

    # @param message [String]
    # @param code [Integer] HTTP status code
    # @param body [String] Response body
    # @param uri [String] Request URI
    def initialize(message, code:, body:, uri:)
      @code = code
      @body = body
      @uri  = uri
      super(message)
    end
  end

  # Raised when a configuration file is missing or malformed.
  class ConfigError < Error; end

  # Raised when IdResolver cannot translate a name to an ID or vice versa.
  class ResolveError < Error; end

  # Raised when a configtest returns ALERT (e.g. HAProxy configtest).
  class ConfigTestError < Error; end
end
