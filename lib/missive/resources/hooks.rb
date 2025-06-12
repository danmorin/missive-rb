# frozen_string_literal: true

module Missive
  module Resources
    # Handles all webhook-related API operations
    #
    # @example Creating a webhook
    #   hook = client.hooks.create(
    #     type: "new_comment",
    #     url: "https://example.com/webhook"
    #   )
    #
    # @example Creating a webhook with filters
    #   hook = client.hooks.create(
    #     type: "incoming_email",
    #     url: "https://example.com/webhook",
    #     mailbox: "inbox-123"
    #   )
    #
    # @example Deleting a webhook
    #   client.hooks.delete(id: "hook-123")
    class Hooks
      CREATE = "/hooks"
      DELETE = "/hooks/%<id>s"

      # Valid webhook types as documented in Missive API
      VALID_TYPES = %w[
        incoming_email
        new_comment
        new_conversation
        conversation_assigned
        conversation_closed
        conversation_reopened
        conversation_moved
        conversation_labeled
        conversation_unlabeled
        message_sent
        message_received
        task_created
        task_updated
        task_completed
      ].freeze

      attr_reader :client

      # @!attribute [r] client
      #   @return [Missive::Client] The API client instance

      # Initialize a new Hooks resource
      # @param client [Missive::Client] The API client instance
      def initialize(client)
        @client = client
      end

      # Create a new webhook
      # @param type [String] Webhook type (must be one of VALID_TYPES)
      # @param url [String] Webhook URL (required)
      # @param filters [Hash] Additional webhook filters and configuration
      # @option filters [String] :mailbox Mailbox ID filter
      # @option filters [String] :organization Organization ID filter
      # @option filters [Array<String>] :teams Team IDs filter
      # @option filters [Array<String>] :users User IDs filter
      # @return [Missive::Object] The created webhook object
      # @raise [ArgumentError] When validation fails
      # @example Create basic webhook
      #   client.hooks.create(type: "new_comment", url: "https://example.com/webhook")
      # @example Create webhook with mailbox filter
      #   client.hooks.create(type: "incoming_email", url: "https://example.com/webhook", mailbox: "inbox-123")
      # rubocop:disable Metrics/AbcSize
      def create(type:, url:, **filters)
        # Validate type
        raise ArgumentError, "type cannot be blank" if type.nil? || type.to_s.strip.empty?
        raise ArgumentError, "type must be one of: #{VALID_TYPES.join(", ")}" unless VALID_TYPES.include?(type.to_s)

        # Validate URL
        raise ArgumentError, "url cannot be blank" if url.nil? || url.to_s.strip.empty?

        # Build hook data
        hook_data = { type: type.to_s, url: url }
        hook_data.merge!(filters) if filters.any?

        body = { hooks: hook_data }

        ActiveSupport::Notifications.instrument("missive.hooks.create", body: body) do
          response = client.connection.request(:post, CREATE, body: body)

          # API returns { hooks: hook_data }
          hook_data = response[:hooks]
          raise Missive::ServerError, "Hook creation failed" unless hook_data

          Missive::Object.new(hook_data, client)
        end
      end
      # rubocop:enable Metrics/AbcSize

      # Delete a webhook
      # @param id [String] Webhook ID (required)
      # @return [Boolean] True on successful deletion
      # @raise [ArgumentError] When id is blank
      # @raise [Missive::NotFoundError] When webhook is not found
      # @example Delete a webhook
      #   client.hooks.delete(id: "hook-123")
      def delete(id:)
        raise ArgumentError, "id cannot be blank" if id.nil? || id.strip.empty?

        path = format(DELETE, id: id)

        ActiveSupport::Notifications.instrument("missive.hooks.delete", id: id) do
          client.connection.request(:delete, path)
          # Successful deletion returns 200/204 with no body
          true
        end
      end
    end
  end
end
