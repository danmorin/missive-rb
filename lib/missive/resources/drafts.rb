# frozen_string_literal: true

module Missive
  module Resources
    # Resource for creating and sending drafts
    class Drafts
      # Path constants
      CREATE = "/drafts"

      # @param client [Missive::Client] The API client instance
      def initialize(client)
        @client = client
      end

      # Create a draft
      #
      # @param body [String] The body of the draft (required)
      # @param to_fields [Array<Hash>] Recipients (required)
      # @param from_field [Hash] Sender information (required)
      # @param subject [String, nil] The subject of the draft
      # @param attrs [Hash] Additional attributes
      # @option attrs [Array<Hash>] :attachments Array of attachment objects
      # @option attrs [String] :references References header value
      # @option attrs [String] :conversation Conversation ID
      # @option attrs [Boolean] :quote_previous_message Whether to quote previous message
      # @return [Missive::Object] The created draft
      # @raise [ArgumentError] If required parameters are missing or invalid
      def create(body:, to_fields:, from_field:, subject: nil, **attrs)
        validate_required_params(body: body, to_fields: to_fields, from_field: from_field)
        validate_attachments(attrs[:attachments]) if attrs[:attachments]
        validate_mutually_exclusive(attrs)

        payload = {
          drafts: {
            subject: subject,
            body: body,
            to_fields: to_fields,
            from_field: from_field,
            **attrs
          }.compact
        }

        ActiveSupport::Notifications.instrument("missive.drafts.create", payload: payload) do
          response = @client.connection.request(:post, CREATE, body: payload)
          Missive::Object.new(response, @client)
        end
      end

      # Send a message (convenience wrapper for create with send: true)
      #
      # @param args [Hash] Same parameters as #create
      # @return [Missive::Object] The sent message
      def send_message(**args)
        create(**args, send: true)
      end

      private

      attr_reader :client

      def validate_required_params(body:, to_fields:, from_field:)
        raise ArgumentError, "body is required" if body.nil? || body.empty?
        raise ArgumentError, "to_fields is required" if to_fields.nil? || to_fields.empty?
        raise ArgumentError, "from_field is required" if from_field.nil? || from_field.empty?
      end

      def validate_attachments(attachments)
        return unless attachments.is_a?(Array)

        attachments.each do |attachment|
          next if attachment.is_a?(Hash) && valid_attachment_content?(attachment)

          raise ArgumentError, "Each attachment must include at least one of: text, markdown, image_url, or fields"
        end
      end

      def valid_attachment_content?(attachment)
        %i[text markdown image_url fields].any? { |key| attachment.key?(key) || attachment.key?(key.to_s) }
      end

      def validate_mutually_exclusive(attrs)
        return unless attrs[:references] && attrs[:conversation]

        raise ArgumentError, "Cannot pass both references and conversation (mutually exclusive)"
      end
    end
  end
end
