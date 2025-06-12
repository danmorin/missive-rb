# frozen_string_literal: true

module Missive
  module Resources
    # Handles all message-related API operations
    #
    # @example Creating a custom channel message
    #   message = client.messages.create_for_custom_channel(
    #     channel_id: "fbf74c47-d0a0-4d77-bf3c-2118025d8102",
    #     from_field: { id: "123", username: "@bot" },
    #     to_fields: [{ id: "321", username: "@user" }],
    #     body: "Hello from custom channel"
    #   )
    #
    # @example Getting a specific message
    #   message = client.messages.get(id: "message-123")
    #
    # @example Finding messages by email message ID
    #   messages = client.messages.list_by_email_message_id(email_message_id: "email-123")
    class Messages
      CREATE = "/messages"
      GET = "/messages/%<id>s"
      LIST = "/messages"

      attr_reader :client

      # @!attribute [r] client
      #   @return [Missive::Client] The API client instance

      # Initialize a new Messages resource
      # @param client [Missive::Client] The API client instance
      def initialize(client)
        @client = client
      end

      # Create a message (primarily for Custom Channel inbound messages)
      # @param account [String] The account/channel ID (required)
      # @param from_field [Hash] The sender information
      # @param to_fields [Array<Hash>] Array of recipient information
      # @param body [String] The message body
      # @param attrs [Hash] Additional message attributes
      # @return [Missive::Object] The created message object
      # @raise [ArgumentError] When required account parameter is missing
      # @example Create a custom channel message
      #   message = client.messages.create(
      #     account: "channel-id",
      #     from_field: { id: "123", username: "@bot" },
      #     to_fields: [{ id: "321", username: "@user" }],
      #     body: "Hello from custom channel"
      #   )
      def create(account:, from_field:, to_fields:, body:, **attrs)
        raise ArgumentError, "account parameter is required" if account.nil? || account.empty?

        message_data = {
          account: account,
          from_field: from_field,
          to_fields: to_fields,
          body: body
        }.merge(attrs)

        ActiveSupport::Notifications.instrument("missive.messages.create", body: message_data) do
          response = client.connection.request(:post, CREATE, body: message_data)

          Missive::Object.new(response, client)
        end
      end

      # Convenience method to create a message for a custom channel
      # @param channel_id [String] The custom channel ID
      # @param attrs [Hash] Message attributes (from_field, to_fields, body, etc.)
      # @return [Missive::Object] The created message object
      # @example Create a custom channel message
      #   message = client.messages.create_for_custom_channel(
      #     channel_id: "fbf74c47-d0a0-4d77-bf3c-2118025d8102",
      #     from_field: { id: "123", username: "@bot" },
      #     to_fields: [{ id: "321", username: "@user" }],
      #     body: "Hello from custom channel"
      #   )
      def create_for_custom_channel(channel_id:, **attrs)
        create(account: channel_id, **attrs)
      end

      # Get a specific message by ID
      # @param id [String] The message ID
      # @return [Missive::Object] The message object
      # @raise [Missive::NotFoundError] When message is not found
      # @example Get a message
      #   message = client.messages.get(id: "message-123")
      #   puts message.body
      def get(id:)
        path = format(GET, id: id)

        ActiveSupport::Notifications.instrument("missive.messages.get", id: id) do
          response = client.connection.request(:get, path)

          # Extract the message data from the response wrapper
          message_data = response[:messages]
          raise Missive::NotFoundError, "Message not found" unless message_data

          Missive::Object.new(message_data, client)
        end
      end

      # List messages by email message ID
      # @param email_message_id [String] The email message ID to search for
      # @return [Array<Missive::Object>] Array of message objects
      # @raise [ArgumentError] When email_message_id is missing or empty
      # @example Find messages by email message ID
      #   messages = client.messages.list_by_email_message_id(email_message_id: "email-123")
      def list_by_email_message_id(email_message_id:)
        raise ArgumentError, "email_message_id is required" if email_message_id.nil? || email_message_id.empty?

        params = { email_message_id: email_message_id }

        ActiveSupport::Notifications.instrument("missive.messages.list", params: params) do
          response = client.connection.request(:get, LIST, params: params)

          # Return array of Missive::Object instances
          (response[:messages] || []).map { |message| Missive::Object.new(message, client) }
        end
      end
    end
  end
end
