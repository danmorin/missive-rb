# frozen_string_literal: true

require "concurrent"

module Missive
  module Middleware
    class RateLimiter < Faraday::Middleware
      def initialize(app, tokens_per_window: Missive::Constants::RATE_60S, window_seconds: 60,
                     soft_limit_threshold: 30)
        super(app)
        @tokens_per_window = tokens_per_window
        @window_seconds = window_seconds
        @soft_limit_threshold = soft_limit_threshold
        @mutex = Mutex.new
        @tokens = tokens_per_window
        @last_refill = Time.now
      end

      def call(env)
        wait_for_token

        response = @app.call(env)

        # Emit notification if remaining tokens are low
        if @tokens <= @soft_limit_threshold
          Missive.configuration.instrumenter.instrument("missive.rate_limit.hit", {
                                                          remaining_tokens: @tokens,
                                                          threshold: @soft_limit_threshold
                                                        })
        end

        # Handle rate limit headers if present
        if response.headers[Missive::Constants::HEADER_RETRY_AFTER]
          sleep_time = response.headers[Missive::Constants::HEADER_RETRY_AFTER].to_i
          sleep(sleep_time) if sleep_time.positive?
        end

        response
      end

      private

      attr_reader :tokens_per_window, :window_seconds, :soft_limit_threshold, :mutex

      def wait_for_token
        @mutex.synchronize do
          refill_tokens

          if @tokens < 1
            sleep_time = (1.0 / tokens_per_window) * window_seconds
            sleep(sleep_time)
            @tokens = 1
          end

          @tokens -= 1
        end
      end

      def refill_tokens
        now = Time.now
        elapsed = now - @last_refill
        tokens_to_add = (elapsed * tokens_per_window / window_seconds).floor

        return unless tokens_to_add.positive?

        @tokens = [@tokens + tokens_to_add, tokens_per_window].min
        @last_refill = now
      end
    end
  end
end
