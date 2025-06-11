# frozen_string_literal: true

module Missive
  class Error < StandardError
    def self.from_status(status, _body)
      case status
      when 401
        AuthenticationError
      when 429
        RateLimitError
      when 500..599
        ServerError
      else
        Error
      end
    end
  end

  class ConfigurationError < Error
  end

  class MissingTokenError < Error
  end

  class AuthenticationError < Error
  end

  class RateLimitError < Error
  end

  class ServerError < Error
  end
end
