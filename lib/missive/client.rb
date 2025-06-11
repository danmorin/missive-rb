# frozen_string_literal: true

require "missive/version"
require "missive/constants"
require "missive/connection"
require "missive/error"
require "missive/resources/analytics"

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
        logger: config[:logger]
      )
    end

    def analytics
      @analytics ||= Missive::Resources::Analytics.new(self)
    end

    def contacts
      @contacts ||= Missive::Resources::Contacts.new(self)
    end

    def contact_books
      @contact_books ||= Missive::Resources::ContactBooks.new(self)
    end

    def contact_groups
      @contact_groups ||= Missive::Resources::ContactGroups.new(self)
    end
  end
end
