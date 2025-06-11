# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"
require "missive/middleware/concurrency_limiter"
require "missive/middleware/rate_limiter"
require "missive/middleware/raise_for_status"
require "missive/middleware/instrumentation"

module Missive
  class Connection
    def initialize(token:, base_url:, timeout: nil, logger: nil)
      @token = token
      @base_url = base_url
      @timeout = timeout
      @logger = logger
    end

    private

    attr_reader :token, :base_url, :timeout, :logger

    def connection
      @connection ||= build_connection
    end

    def build_connection
      Faraday.new(url: base_url) do |builder|
        # Instrumentation (first)
        builder.use Missive::Middleware::Instrumentation

        # Request middleware
        builder.request :json
        builder.use Missive::Middleware::ConcurrencyLimiter
        builder.use Missive::Middleware::RateLimiter
        builder.request :retry,
                        max: 3,
                        interval: 0.3,
                        interval_randomness: 0.0,
                        backoff_factor: 3,
                        retry_statuses: [429, 500, 502, 503, 504],
                        methods: %i[get post patch delete]

        # Response middleware
        builder.response :json, parser_options: { symbolize_names: true }
        builder.use Missive::Middleware::RaiseForStatus

        # Headers
        builder.headers["Authorization"] = "Bearer #{token}"
        builder.headers["User-Agent"] = "missive-rb/#{Missive::VERSION}"
        builder.headers["Content-Type"] = "application/json"

        # Timeout
        builder.options.timeout = timeout if timeout

        # Adapter (default)
        builder.adapter Faraday.default_adapter
      end
    end

    public

    def request(method, path, params: {}, body: nil)
      # Strip leading slash to prevent Faraday from treating it as absolute path
      path = path.sub(/^\//, '') if path.start_with?('/')
      
      response = connection.public_send(method, path) do |req|
        req.params = params if params.any?
        req.body = body if body
      end
      response.body
    end
  end
end
