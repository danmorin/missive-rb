# frozen_string_literal: true

require "missive/version"
require "missive/constants"
require "missive/connection"
require "missive/error"

module Missive
  class Client
    attr_reader :config, :token

    def initialize(api_token:, base_url: Missive::Constants::BASE_URL, **options)
      raise MissingTokenError, "api_token cannot be nil" if api_token.nil?

      @token = api_token
      @config = { base_url: base_url, **options }.freeze
    end

    def connection
      @connection ||= Missive::Connection.new(
        token: token,
        base_url: config[:base_url],
        timeout: config[:timeout],
        logger: config[:logger],
        rate_limit_tokens: config[:rate_limit_tokens] || 300
      )
    end
  end
end
