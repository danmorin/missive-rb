# frozen_string_literal: true

module Missive
  module Resources
    # Resource for creating and deleting posts
    class Posts
      # Path constants
      CREATE = "/posts"
      DELETE = "/posts/%<id>s"

      # Conversation-state attributes that, when present, satisfy the
      # content requirement on their own (a metadata-only post is valid
      # per Missive's REST API when its purpose is to mutate conversation
      # state rather than render visible content).
      CONVERSATION_ACTION_KEYS = %i[
        close
        reopen
        add_assignees
        add_shared_labels
        remove_shared_labels
        add_to_inbox
        add_to_team_inbox
      ].freeze

      # @param client [Missive::Client] The API client instance
      def initialize(client)
        @client = client
      end

      # Create a post
      #
      # A post is the canonical way to mutate a conversation in Missive's
      # REST API. It can carry visible content (text/markdown/attachments),
      # mutate conversation state (close, reopen, label changes, assignee
      # changes, inbox moves), or both. At least one of those must be
      # present.
      #
      # @param text [String, nil] Plain text content
      # @param markdown [String, nil] Markdown content
      # @param attachments [Array<Hash>, nil] Array of attachment objects
      # @param attrs [Hash] Additional attributes (e.g. :conversation, :close,
      #   :reopen, :add_shared_labels, :remove_shared_labels, :add_assignees,
      #   :add_to_inbox, :add_to_team_inbox, :team, :notification, :organization)
      # @option attrs [Hash] :notification Notification settings (must include title and body)
      # @return [Missive::Object] The created post
      # @raise [ArgumentError] If neither content (text/markdown/attachments)
      #   nor a conversation-action attribute is provided, or if notification
      #   is invalid
      def create(text: nil, markdown: nil, attachments: nil, **attrs)
        validate_content_or_action!(text: text, markdown: markdown, attachments: attachments, attrs: attrs)
        validate_notification(attrs[:notification]) if attrs[:notification]

        payload = {
          posts: {
            text: text,
            markdown: markdown,
            attachments: attachments,
            **attrs
          }.compact
        }

        ActiveSupport::Notifications.instrument("missive.posts.create", payload: payload) do
          response = @client.connection.request(:post, CREATE, body: payload)
          Missive::Object.new(response, @client)
        end
      end

      # Delete a post
      #
      # @param id [String] The post ID to delete
      # @return [Boolean] True if deletion was successful
      # @raise [Missive::NotFoundError] If the post was not found
      def delete(id:)
        path = format(DELETE, id: id)

        ActiveSupport::Notifications.instrument("missive.posts.delete", id: id) do
          @client.connection.request(:delete, path)
          true
        end
      end

      private

      attr_reader :client

      def validate_content_or_action!(text:, markdown:, attachments:, attrs:)
        return if text || markdown || attachments
        return if CONVERSATION_ACTION_KEYS.any? { |key| attrs.key?(key) }

        raise ArgumentError,
              "At least one of text, markdown, attachments, or a conversation-action " \
              "attribute (#{CONVERSATION_ACTION_KEYS.join(", ")}) is required"
      end

      def validate_notification(notification)
        return unless notification.is_a?(Hash)
        return if notification[:title] && notification[:body]

        raise ArgumentError, "Notification must include title and body"
      end
    end
  end
end
