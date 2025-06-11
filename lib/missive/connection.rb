# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"
require "mutex_m"
require "concurrent"

module Missive
  class Connection
    include Mutex_m

    def initialize(token:, base_url:, timeout: nil, logger: nil, rate_limit_tokens: 300)
      super()
      @token = token
      @base_url = base_url
      @timeout = timeout
      @logger = logger
      @semaphore = Concurrent::Semaphore.new(Missive::Constants::MAX_CONCURRENCY)

      # Token bucket for rate limiting
      @tokens = rate_limit_tokens
      @max_tokens = rate_limit_tokens
      @timestamp = Time.now
    end

    private

    attr_reader :token, :base_url, :timeout, :logger, :semaphore
    attr_accessor :tokens, :max_tokens, :timestamp

    def connection
      @connection ||= synchronize do
        @connection || build_connection
      end
    end

    def build_connection
      Faraday.new(url: base_url) do |builder|
        # Request middleware
        builder.request :json
        builder.request :retry,
                        max: 3,
                        interval: 0.3,
                        interval_randomness: 0.0,
                        backoff_factor: 3,
                        retry_statuses: [429, 500, 502, 503, 504]

        # Response middleware
        builder.response :raise_error
        builder.response :json, parser_options: { symbolize_names: true }

        # Headers
        builder.headers["Authorization"] = "Bearer #{token}"
        builder.headers["User-Agent"] = "Missive Ruby Client #{Missive::VERSION}"
        builder.headers["Content-Type"] = "application/json"

        # Timeout
        builder.options.timeout = timeout if timeout

        # Adapter (default)
        builder.adapter Faraday.default_adapter
      end
    end

    def rate_limit_guard
      synchronize do
        now = Time.now
        elapsed = now - timestamp

        # Refill tokens based on elapsed time: 300 tokens per 60 seconds = 5 tokens per second
        tokens_to_add = (elapsed * max_tokens / 60.0).floor
        self.tokens = [tokens + tokens_to_add, max_tokens].min
        self.timestamp = now

        # If not enough tokens, wait until we can proceed
        if tokens < 1
          sleep_time = (1 - tokens) * 60.0 / max_tokens
          sleep(sleep_time)
          self.tokens = 1
        end

        # Consume one token
        self.tokens -= 1
      end
    end

    public

    def request(method, path, params: {}, body: nil)
      rate_limit_guard

      semaphore.acquire
      begin
        response = connection.public_send(method, path) do |req|
          req.params = params if params.any?
          req.body = body if body
        end
        response.body
      ensure
        semaphore.release
      end
    rescue Faraday::Error => e
      status = e.response&.dig(:status) || 0
      response_body = e.response&.dig(:body) || {}
      error_class = Missive::Error.from_status(status, response_body)
      raise error_class, e.message
    end
  end
end
