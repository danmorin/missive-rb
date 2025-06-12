# frozen_string_literal: true

require "logger"
require "active_support/notifications"

module Missive
  # Configuration class for the Missive client library
  #
  # Manages all configuration options including logging, instrumentation,
  # rate limiting, caching, and webhook signature validation.
  #
  # @example Basic configuration
  #   Missive.configure do |config|
  #     config.api_token = "your-api-token"
  #     config.cache_enabled = true
  #   end
  #
  # @example Advanced configuration with custom cache store
  #   Missive.configure do |config|
  #     config.api_token = "your-api-token"
  #     config.cache_enabled = true
  #     config.cache_store = ActiveSupport::Cache::RedisStore.new
  #     config.soft_limit_threshold = 50
  #   end
  class Configuration
    # @!attribute [rw] logger
    #   @return [Logger] Logger instance for debug and error output
    attr_accessor :logger

    # @!attribute [rw] instrumenter
    #   @return [Object] Instrumenter for emitting notification events (defaults to ActiveSupport::Notifications)
    attr_accessor :instrumenter

    # @!attribute [rw] token_lookup
    #   @return [Proc] Lambda for looking up API tokens by email (defaults to no-op)
    attr_accessor :token_lookup

    # @!attribute [rw] base_url
    #   @return [String] Base URL for the Missive API
    attr_accessor :base_url

    # @!attribute [rw] soft_limit_threshold
    #   @return [Integer] Threshold for rate limit soft warnings (defaults to 30)
    attr_accessor :soft_limit_threshold

    # @!attribute [rw] api_token
    #   @return [String, nil] API token for authentication
    attr_accessor :api_token

    # @!attribute [rw] signature_secrets
    #   @return [Hash] Hash of webhook signature secrets for validation
    attr_accessor :signature_secrets

    # @!attribute [rw] cache_store
    #   @return [Object, nil] Cache store for HTTP response caching (must respond to read/write/delete)
    attr_accessor :cache_store

    # @!attribute [rw] cache_enabled
    #   @return [Boolean] Whether HTTP caching is enabled (defaults to false)
    attr_accessor :cache_enabled

    # Initialize configuration with default values
    #
    # Sets up sensible defaults for all configuration options including
    # a stdout logger, ActiveSupport::Notifications instrumenter, and
    # disabled caching for backward compatibility.
    #
    # @return [Configuration] New configuration instance with defaults
    def initialize
      @logger = Logger.new($stdout).tap { |l| l.level = Logger::INFO }
      @instrumenter = ActiveSupport::Notifications
      @token_lookup = ->(_email) {}
      @base_url = Missive::Constants::BASE_URL
      @soft_limit_threshold = 30
      @api_token = nil
      @signature_secrets = {}
      @cache_store = nil
      @cache_enabled = false
    end

    # Freeze the configuration to prevent further modifications
    #
    # Deep freezes all instance variables to ensure configuration
    # immutability after initialization is complete.
    #
    # @return [Configuration] The frozen configuration instance
    def freeze
      instance_variables.each do |var|
        instance_variable_get(var).freeze
      end
      super
    end
  end
end
