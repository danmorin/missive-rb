# frozen_string_literal: true

begin
  require "rails/railtie"
rescue LoadError
  # Mock Rails::Railtie if Rails is not available
  module Rails
    class Railtie
      def self.initializer(name, &)
        # No-op when Rails is not available
      end

      def self.generators(&)
        # No-op when Rails is not available
      end
    end
  end
end

module Missive
  # Rails integration for Missive Ruby SDK
  #
  # Provides automatic configuration, logging, and generator support
  # when using the Missive gem in a Rails application.
  class Railtie < Rails::Railtie
    # Configure Missive with Rails credentials if available
    initializer "missive.configure" do |app|
      # Set default API token from Rails credentials if none provided
      if Missive.configuration.api_token.nil?
        credentials_token = app.credentials.dig(:missive, :api_token)
        if credentials_token
          Missive.configure do |config|
            config.api_token = credentials_token
          end
        end
      end

      # Set default signature secrets from Rails credentials if none provided
      if Missive.configuration.signature_secrets.empty?
        webhook_secret = app.credentials.dig(:missive, :webhook_secret)
        channel_secret = app.credentials.dig(:missive, :channel_secret)

        if webhook_secret || channel_secret
          Missive.configure do |config|
            config.signature_secrets = {
              webhooks: webhook_secret,
              custom_channels: channel_secret
            }.compact
          end
        end
      end
    end

    # Subscribe to Missive notifications for logging
    initializer "missive.log_subscriber" do
      ActiveSupport::Notifications.subscribe(/^missive\./) do |name, start, finish, _id, payload|
        duration = ((finish - start) * 1000).round(2)

        Rails.logger.tagged("[MISSIVE]") do
          case name
          when /\.update$/, /\.delete$/, /\.get$/
            Rails.logger.info "#{name} completed in #{duration}ms (id: #{payload[:id]})"
          when /\.list$/
            Rails.logger.info "#{name} completed in #{duration}ms (params: #{payload[:params]})"
          else
            Rails.logger.info "#{name} completed in #{duration}ms"
          end
        end
      end
    end

    # Make generators available
    generators do
      require "missive/generators/install_generator"
    end
  end
end
