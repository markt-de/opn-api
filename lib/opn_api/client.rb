# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'openssl'

module OpnApi
  # HTTP client for communicating with the OPNsense REST API.
  #
  # Supports SSL, redirect following (301/302/307/308), configurable
  # timeouts, and basic authentication with API key/secret.
  #
  # @example Direct instantiation
  #   client = OpnApi::Client.new(
  #     url: 'https://opnsense01.example.com/api',
  #     api_key: '+ABC...', api_secret: '+XYZ...',
  #     ssl_verify: false,
  #   )
  #   result = client.get('firmware/info/running')
  #
  # @example From Config
  #   config = OpnApi::Config.new
  #   client = config.client_for('opnsense01')
  class Client
    DEFAULT_URL = 'http://localhost:80/api'
    MAX_REDIRECTS = 5

    # @param url [String] Base URL of the OPNsense API (e.g. 'https://opnsense01.example.com/api')
    # @param api_key [String] OPNsense API key
    # @param api_secret [String] OPNsense API secret
    # @param ssl_verify [Boolean] Whether to verify SSL certificates (default: true)
    # @param timeout [Integer] HTTP timeout in seconds (default: 60)
    def initialize(url:, api_key:, api_secret:, ssl_verify: true, timeout: 60)
      @url        = url.to_s.chomp('/')
      @api_key    = api_key
      @api_secret = api_secret
      @ssl_verify = ssl_verify
      @timeout    = timeout.to_i
    end

    # Performs an HTTP GET request to the OPNsense API.
    #
    # @param path [String] API path (relative, e.g. 'firewall/alias/search_item')
    # @param raw [Boolean] If true, return raw response body instead of parsing JSON
    # @return [Hash, String] Parsed JSON response, or raw body string when raw: true
    def get(path, raw: false)
      uri = build_uri(path)
      OpnApi.logger.debug("GET #{uri}")
      http_request(:get, uri, nil, 0, raw: raw)
    end

    # Performs an HTTP POST request to the OPNsense API.
    #
    # @param path [String] API path (relative)
    # @param data [Hash] Request body (serialized as JSON)
    # @return [Hash] Parsed JSON response
    def post(path, data = {})
      uri = build_uri(path)
      OpnApi.logger.debug("POST #{uri} body=#{data.to_json}")
      http_request(:post, uri, data)
    end

    private

    # Executes an HTTP request, following redirects transparently.
    # OPNsense commonly issues 308 redirects when HTTP is used but HTTPS is required.
    #
    # @param method [Symbol] :get or :post
    # @param uri [URI] Fully qualified URI
    # @param data [Hash, nil] POST body data
    # @param redirect_count [Integer] Internal redirect counter
    # @param raw [Boolean] If true, return raw response body instead of parsing JSON
    # @return [Hash, String] Parsed JSON response, or raw body string when raw: true
    def http_request(method, uri, data = nil, redirect_count = 0, raw: false)
      if redirect_count > MAX_REDIRECTS
        raise OpnApi::ConnectionError, "Too many redirects (> #{MAX_REDIRECTS}) for '#{uri}'"
      end

      http = build_http(uri)
      request = build_request(method, uri, data)
      request.basic_auth(@api_key, @api_secret)
      request['Accept'] = 'application/json'
      request['Content-Type'] = 'application/json' if method == :post

      response = http.request(request)
      code = response.code.to_i

      # Handle redirects: 307/308 preserve method+body, 301/302 switch to GET
      if [301, 302, 307, 308].include?(code)
        location = response['location']
        unless location
          raise OpnApi::ConnectionError,
                "#{code} redirect with no Location header for '#{uri}'"
        end

        OpnApi.logger.debug("Following #{code} redirect to '#{location}'")
        new_uri = URI.parse(location)

        if [307, 308].include?(code)
          return http_request(method, new_uri, data, redirect_count + 1, raw: raw)
        end

        return http_request(:get, new_uri, nil, redirect_count + 1, raw: raw)
      end

      # Raw mode: skip JSON parsing, return body as string
      return handle_raw_response(response, uri.to_s) if raw

      handle_response(response, uri.to_s)
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT => e
      raise OpnApi::ConnectionError, "Connection failed for '#{uri}': #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise OpnApi::TimeoutError, "Timeout for '#{uri}': #{e.message}"
    end

    # Builds a full URI from the base URL and a relative path.
    def build_uri(path)
      clean_path = path.to_s.sub(%r{^/+}, '')
      URI.parse("#{@url}/#{clean_path}")
    rescue URI::InvalidURIError => e
      raise OpnApi::ConnectionError, "Invalid API path '#{path}': #{e.message}"
    end

    # Creates a Net::HTTP instance with SSL and timeout settings.
    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = @timeout
      http.read_timeout = @timeout

      if uri.scheme == 'https'
        http.use_ssl = true
        http.verify_mode = @ssl_verify ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      end

      http
    end

    # Builds a Net::HTTP request object for the given method.
    def build_request(method, uri, data)
      case method
      when :get
        Net::HTTP::Get.new(uri)
      when :post
        req = Net::HTTP::Post.new(uri)
        req.body = data.to_json
        req
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end
    end

    # Returns raw response body after checking HTTP status.
    # Used for non-JSON endpoints (e.g. XML backup downloads).
    #
    # @param response [Net::HTTPResponse]
    # @param request_uri [String]
    # @return [String] Raw response body
    def handle_raw_response(response, request_uri)
      code = response.code.to_i
      unless (200..299).cover?(code)
        raise OpnApi::ApiError.new(
          "API error #{code} for '#{request_uri}': #{response.body}",
          code: code,
          body: response.body.to_s,
          uri: request_uri,
        )
      end

      OpnApi.logger.debug("Response #{code} (raw, #{response.body.to_s.bytesize} bytes)")
      response.body.to_s
    end

    # Parses and validates an HTTP response.
    #
    # @param response [Net::HTTPResponse]
    # @param request_uri [String]
    # @return [Hash] Parsed JSON body
    def handle_response(response, request_uri)
      code = response.code.to_i
      unless (200..299).cover?(code)
        raise OpnApi::ApiError.new(
          "API error #{code} for '#{request_uri}': #{response.body}",
          code: code,
          body: response.body.to_s,
          uri: request_uri,
        )
      end

      body = response.body
      return {} if body.nil? || body.strip.empty?

      OpnApi.logger.debug("Response #{code} body=#{body.strip}")
      JSON.parse(body)
    rescue JSON::ParserError => e
      raise OpnApi::ApiError.new(
        "Response parse error for '#{request_uri}': #{e.message}",
        code: code,
        body: body.to_s,
        uri: request_uri,
      )
    end
  end
end
