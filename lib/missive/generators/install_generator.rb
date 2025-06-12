# frozen_string_literal: true

begin
  require "rails/generators"
rescue LoadError
  # Rails generators not available - define minimal stubs
  unless defined?(Rails::Generators)
    Rails = Module.new unless defined?(Rails)
    Rails.const_set(:Generators, Module.new) unless Rails.const_defined?(:Generators)
    unless Rails::Generators.const_defined?(:Base)
      Rails::Generators.const_set(:Base, Class.new do
        def self.source_root(path = nil)
          # Stub implementation
        end

        def self.desc(description)
          # Stub implementation
        end

        def create_file(path, content)
          # Stub implementation
        end
      end)
    end
  end
end

module Missive
  module Generators
    # Rails generator for creating Missive configuration files
    #
    # @example Generate initializer
    #   rails generate missive:install
    class InstallGenerator < Rails::Generators::Base
      desc "Creates a Missive initializer file at config/initializers/missive.rb"

      def self.source_root
        @source_root ||= File.expand_path("templates", __dir__)
      end

      # Create the initializer file
      def create_initializer_file
        create_file "config/initializers/missive.rb", initializer_content
      end

      private

      # Template content for the initializer
      def initializer_content
        <<~RUBY
          # frozen_string_literal: true

          # Missive API Configuration
          # For more information, see: https://learn.missiveapp.com/api-documentation

          Missive.configure do |config|
            # API Token (required for API requests)
            # You can set this in Rails credentials or environment variables
            # config.api_token = Rails.application.credentials.dig(:missive, :api_token)
            # config.api_token = ENV['MISSIVE_API_TOKEN']

            # Webhook signature validation secrets
            # These are used to verify webhook authenticity
            config.signature_secrets = {
              webhooks:        ENV['MISSIVE_WEBHOOK_SECRET'],
              custom_channels: ENV['MISSIVE_CHANNEL_SECRET']
            }

            # Optional: Configure request timeout (default: 30 seconds)
            # config.timeout = 30

            # Optional: Configure base URL (default: https://public-api.missiveapp.com/v1)
            # config.base_url = "https://public-api.missiveapp.com/v1"

            # Optional: Configure custom logger
            # config.logger = Logger.new($stdout)
          end

          # Optional: Rails credential setup example
          # Add to config/credentials.yml.enc:
          #
          # missive:
          #   api_token: your_api_token_here
          #   webhook_secret: your_webhook_secret_here
          #   channel_secret: your_channel_secret_here
        RUBY
      end
    end
  end
end
