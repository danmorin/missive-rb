# frozen_string_literal: true

require "json"
require "rack"

module Missive
  # Rack middleware for handling Missive webhooks with signature validation
  #
  # @example Basic usage in Sinatra
  #   use Missive::WebhookServer, signature_secret: "your-secret"
  #
  # @example Using the mount helper
  #   app = Missive::WebhookServer.mount("/webhooks", "your-secret")
  #   run app
  #
  # @example In Rails config/application.rb
  #   config.middleware.use Missive::WebhookServer, signature_secret: ENV['MISSIVE_WEBHOOK_SECRET']
  class WebhookServer
    # Error returned when signature validation fails
    INVALID_SIGNATURE_ERROR = { error: "invalid_signature" }.freeze

    attr_reader :app, :signature_secret

    # Initialize the webhook server middleware
    # @param app [#call] The Rack application
    # @param signature_secret [String] Secret for HMAC signature validation (required)
    # @raise [ArgumentError] When signature_secret is nil or empty
    def initialize(app, signature_secret:)
      raise ArgumentError, "signature_secret cannot be blank" if signature_secret.nil? || signature_secret.strip.empty?

      @app = app
      @signature_secret = signature_secret
    end

    # Process the Rack request
    # @param env [Hash] The Rack environment
    # @return [Array] Rack response array [status, headers, body]
    def call(env)
      # Read the raw request body
      request = Rack::Request.new(env)
      body = request.body.read
      request.body.rewind

      # Get the signature from headers
      received_signature = env["HTTP_X_HOOK_SIGNATURE"]

      # Validate signature
      return invalid_signature_response unless valid_signature?(body, received_signature)

      # Parse and store webhook data
      begin
        webhook_data = JSON.parse(body, symbolize_names: true)
        env["missive.webhook"] = webhook_data
      rescue JSON::ParserError
        # If JSON parsing fails, continue without webhook data
        env["missive.webhook"] = nil
      end

      # Call the next middleware/app
      @app.call(env)
    end

    # Helper method to mount webhook server with a specific path
    # @param path [String] The path to mount the webhook server on
    # @param secret [String] The signature secret
    # @return [Rack::Builder] A Rack builder instance ready to run
    # @example Mount on /webhooks path
    #   app = Missive::WebhookServer.mount("/webhooks", "secret")
    #   run app
    def self.mount(path, secret)
      Rack::Builder.new do
        map path do
          use Missive::WebhookServer, signature_secret: secret
          run lambda { |_env|
            [200, { "Content-Type" => "application/json" }, ['{"status":"ok"}']]
          }
        end
      end
    end

    private

    # Validate the HMAC signature
    # @param body [String] The raw request body
    # @param received_signature [String] The signature from the X-Hook-Signature header
    # @return [Boolean] True if signature is valid
    def valid_signature?(body, received_signature)
      return false if received_signature.nil? || received_signature.empty?

      expected_signature = Missive::Signature.generate(body, signature_secret)

      # Use secure comparison to prevent timing attacks
      Rack::Utils.secure_compare(expected_signature, received_signature)
    end

    # Return a 403 response for invalid signatures
    # @return [Array] Rack response for invalid signature
    def invalid_signature_response
      [
        403,
        { "Content-Type" => "application/json" },
        [JSON.generate(INVALID_SIGNATURE_ERROR)]
      ]
    end
  end
end
