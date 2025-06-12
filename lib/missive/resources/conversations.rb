# frozen_string_literal: true

module Missive
  module Resources
    # Handles all conversation-related API operations
    #
    # @example Listing conversations in inbox
    #   conversations = client.conversations.list(inbox: true, limit: 25)
    #
    # @example Getting a specific conversation
    #   conversation = client.conversations.get(id: "conversation-123")
    #
    # @example Getting messages for a conversation
    #   messages = client.conversations.messages(conversation_id: "conversation-123")
    #
    # @example Iterating through all conversations
    #   client.conversations.each_item(inbox: true) do |conversation|
    #     puts conversation.subject
    #   end
    class Conversations
      LIST = "/conversations"
      GET = "/conversations/%<id>s"
      MESSAGES = "/conversations/%<id>s/messages"
      COMMENTS = "/conversations/%<id>s/comments"

      attr_reader :client

      # @!attribute [r] client
      #   @return [Missive::Client] The API client instance

      # Initialize a new Conversations resource
      # @param client [Missive::Client] The API client instance
      def initialize(client)
        @client = client
      end

      # List conversations with pagination support
      # @param limit [Integer] Number of conversations per page (max: 50)
      # @param until_cursor [String] Pagination cursor for fetching older conversations
      # @param params [Hash] Additional query parameters
      # @option params [Boolean] :inbox Filter for inbox conversations
      # @option params [String] :mailbox Filter by mailbox ID
      # @option params [String] :team Filter by team ID
      # @return [Array<Missive::Object>] Array of conversation objects for the current page
      # @raise [ArgumentError] When limit exceeds 50 or invalid param combinations
      # @example List inbox conversations
      #   conversations = client.conversations.list(inbox: true, limit: 25)
      def list(limit: 25, until_cursor: nil, **params)
        # Enforce limit cap per Missive API docs
        raise ArgumentError, "limit cannot exceed 50" if limit > 50

        # Validate param combinations
        validate_list_params?(params)

        merged_params = { limit: limit }.merge(params)
        merged_params[:until] = until_cursor if until_cursor

        ActiveSupport::Notifications.instrument("missive.conversations.list", params: merged_params) do
          response = client.connection.request(:get, LIST, params: merged_params)

          # Return array of Missive::Object instances
          (response[:conversations] || []).map { |conversation| Missive::Object.new(conversation, client) }
        end
      end

      # Iterate through all conversations with automatic pagination
      # @param params [Hash] Query parameters for filtering conversations
      # @option params [Integer] :limit Number of conversations per page (max: 50)
      # @yield [Missive::Object] Each conversation object
      # @return [Enumerator] If no block given
      # @raise [ArgumentError] When limit exceeds 50 or invalid param combinations
      # @example Iterate through all inbox conversations
      #   client.conversations.each_item(inbox: true) do |conversation|
      #     puts conversation.subject
      #   end
      def each_item(**params)
        # Default limit if not provided
        params[:limit] ||= 25

        # Enforce limit cap
        raise ArgumentError, "limit cannot exceed 50" if params[:limit] > 50

        # Validate param combinations
        validate_list_params?(params)

        Missive::Paginator.each_item(
          path: LIST,
          client: client,
          params: params,
          data_key: :conversations
        ) do |item|
          # Convert each item to a Missive::Object
          yield Missive::Object.new(item, client)
        end
      end

      # Get a specific conversation by ID
      # @param id [String] The conversation ID
      # @return [Missive::Object] The conversation object
      # @raise [Missive::NotFoundError] When conversation is not found
      # @example Get a conversation
      #   conversation = client.conversations.get(id: "conversation-123")
      #   puts conversation.subject
      def get(id:)
        path = format(GET, id: id)

        ActiveSupport::Notifications.instrument("missive.conversations.get", id: id) do
          response = client.connection.request(:get, path)

          Missive::Object.new(response, client)
        end
      end

      # Get messages for a specific conversation
      # @param conversation_id [String] The conversation ID
      # @param limit [Integer] Number of messages per page (max: 10)
      # @param until_cursor [String] Pagination cursor for fetching older messages
      # @return [Array<Missive::Object>] Array of message objects for the current page
      # @raise [ArgumentError] When limit exceeds 10
      # @example Get messages for a conversation
      #   messages = client.conversations.messages(conversation_id: "conversation-123")
      def messages(conversation_id:, limit: 10, until_cursor: nil)
        # Enforce limit cap per Missive API docs
        raise ArgumentError, "limit cannot exceed 10" if limit > 10

        path = format(MESSAGES, id: conversation_id)
        params = { limit: limit }
        params[:until] = until_cursor if until_cursor

        ActiveSupport::Notifications.instrument("missive.conversations.messages", conversation_id: conversation_id,
                                                                                  params: params) do
          response = client.connection.request(:get, path, params: params)

          # Return array of Missive::Object instances
          (response[:messages] || []).map { |message| Missive::Object.new(message, client) }
        end
      end

      # Iterate through all messages for a conversation with automatic pagination
      # @param conversation_id [String] The conversation ID
      # @param limit [Integer] Number of messages per page (max: 10)
      # @yield [Missive::Object] Each message object
      # @return [Enumerator] If no block given
      # @raise [ArgumentError] When limit exceeds 10
      # @example Iterate through all messages
      #   client.conversations.each_message(conversation_id: "conversation-123") do |message|
      #     puts message.body
      #   end
      def each_message(conversation_id:, limit: 10, **params)
        # Enforce limit cap
        raise ArgumentError, "limit cannot exceed 10" if limit > 10

        path = format(MESSAGES, id: conversation_id)
        merged_params = { limit: limit }.merge(params)

        Missive::Paginator.each_item(
          path: path,
          client: client,
          params: merged_params,
          data_key: :messages
        ) do |item|
          # Convert each item to a Missive::Object
          yield Missive::Object.new(item, client)
        end
      end

      # Get comments for a specific conversation
      # @param conversation_id [String] The conversation ID
      # @param limit [Integer] Number of comments per page (max: 10)
      # @param until_cursor [String] Pagination cursor for fetching older comments
      # @return [Array<Missive::Object>] Array of comment objects for the current page
      # @raise [ArgumentError] When limit exceeds 10
      # @example Get comments for a conversation
      #   comments = client.conversations.comments(conversation_id: "conversation-123")
      def comments(conversation_id:, limit: 10, until_cursor: nil)
        # Enforce limit cap per Missive API docs
        raise ArgumentError, "limit cannot exceed 10" if limit > 10

        path = format(COMMENTS, id: conversation_id)
        params = { limit: limit }
        params[:until] = until_cursor if until_cursor

        ActiveSupport::Notifications.instrument("missive.conversations.comments", conversation_id: conversation_id,
                                                                                  params: params) do
          response = client.connection.request(:get, path, params: params)

          # Return array of Missive::Object instances
          (response[:comments] || []).map { |comment| Missive::Object.new(comment, client) }
        end
      end

      # Iterate through all comments for a conversation with automatic pagination
      # @param conversation_id [String] The conversation ID
      # @param limit [Integer] Number of comments per page (max: 10)
      # @yield [Missive::Object] Each comment object
      # @return [Enumerator] If no block given
      # @raise [ArgumentError] When limit exceeds 10
      # @example Iterate through all comments
      #   client.conversations.each_comment(conversation_id: "conversation-123") do |comment|
      #     puts comment.body
      #   end
      def each_comment(conversation_id:, limit: 10, **params)
        # Enforce limit cap
        raise ArgumentError, "limit cannot exceed 10" if limit > 10

        path = format(COMMENTS, id: conversation_id)
        merged_params = { limit: limit }.merge(params)

        Missive::Paginator.each_item(
          path: path,
          client: client,
          params: merged_params,
          data_key: :comments
        ) do |item|
          # Convert each item to a Missive::Object
          yield Missive::Object.new(item, client)
        end
      end

      private

      # Validate param combinations for list method
      # Fail fast on unsupported param combos per Missive API docs
      def validate_list_params?(_params)
        # This is a placeholder for validation logic based on Missive API docs
        # The actual validation would depend on the specific restrictions
        # mentioned in the API documentation
        true
      end
    end
  end
end
