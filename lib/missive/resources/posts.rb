# frozen_string_literal: true

module Missive
  module Resources
    # Resource for creating and deleting posts
    class Posts
      # Path constants
      CREATE = "/posts"
      DELETE = "/posts/%<id>s"

      # @param client [Missive::Client] The API client instance
      def initialize(client)
        @client = client
      end

      # Create a post
      #
      # @param text [String, nil] Plain text content
      # @param markdown [String, nil] Markdown content
      # @param attachments [Array<Hash>, nil] Array of attachment objects
      # @param attrs [Hash] Additional attributes
      # @option attrs [Hash] :notification Notification settings (must include title and body)
      # @return [Missive::Object] The created post
      # @raise [ArgumentError] If none of the content keys are provided or notification is invalid
      def create(text: nil, markdown: nil, attachments: nil, **attrs)
        validate_content_present(text: text, markdown: markdown, attachments: attachments)
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

      def validate_content_present(text:, markdown:, attachments:)
        return if text || markdown || attachments

        raise ArgumentError, "At least one of text, markdown, or attachments is required"
      end

      def validate_notification(notification)
        return unless notification.is_a?(Hash)
        return if notification[:title] && notification[:body]

        raise ArgumentError, "Notification must include title and body"
      end
    end
  end
end
