# frozen_string_literal: true

require "concurrent"

module Missive
  module Middleware
    class ConcurrencyLimiter < Faraday::Middleware
      def initialize(app, max_concurrent: Missive::Constants::MAX_CONCURRENCY)
        super(app)
        @semaphore = Concurrent::Semaphore.new(max_concurrent)
      end

      def call(env)
        @semaphore.acquire
        begin
          @app.call(env)
        ensure
          @semaphore.release
        end
      end

      private

      attr_reader :semaphore
    end
  end
end
