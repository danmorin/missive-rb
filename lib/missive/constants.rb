# frozen_string_literal: true

module Missive
  module Constants
    BASE_URL = "https://public-api.missiveapp.com/v1"
    MAX_CONCURRENCY = 5
    RATE_60S = 300
    RATE_15M = 900
    HEADER_RETRY_AFTER = "Retry-After"
    HEADER_RATE_LIMIT_REMAINING = "X-RateLimit-Remaining"
    HEADER_RATE_LIMIT_RESET = "X-RateLimit-Reset"
  end
end
