# frozen_string_literal: true

module Missive
  module Resources
    # Resource for creating and sending drafts via the Missive API
    #
    # Supports email, SMS, WhatsApp, and custom channels with comprehensive
    # scheduling, team management, and attachment handling.
    class Drafts
      # Path constants
      CREATE = "/drafts"

      # Maximum number of attachments allowed per draft
      MAX_ATTACHMENTS = 25

      # @param client [Missive::Client] The API client instance
      def initialize(client)
        @client = client
      end

      # Create a draft
      #
      # @param body [String] HTML or text body content (required)
      # @param to_fields [Array<Hash>] Recipients array (required)
      # @param from_field [Hash] Sender information (required)
      # @param subject [String, nil] Draft subject
      # @param quote_previous_message [Boolean] Include quoted previous message
      # @param cc_fields [Array<Hash>] CC recipients (email only)
      # @param bcc_fields [Array<Hash>] BCC recipients (email only)
      # @param account [String] Account ID for custom channels
      # @param attachments [Array<Hash>] File attachments (max 25)
      # @param references [Array<String>] Message references for threading
      # @param conversation [String] Conversation ID to append to
      # @param team [String] Team ID
      # @param force_team [Boolean] Force team assignment
      # @param organization [String] Organization ID
      # @param add_users [Array<String>] User IDs to add to conversation
      # @param add_assignees [Array<String>] User IDs to assign
      # @param conversation_subject [String] Conversation subject
      # @param conversation_color [String] Conversation color (hex or 'good'/'warning'/'danger')
      # @param add_shared_labels [Array<String>] Shared label IDs to add
      # @param remove_shared_labels [Array<String>] Shared label IDs to remove
      # @param add_to_inbox [Boolean] Move to inbox
      # @param add_to_team_inbox [Boolean] Move to team inbox
      # @param close [Boolean] Close conversation
      # @param send [Boolean] Send draft immediately
      # @param send_at [Integer] Unix timestamp for scheduled sending
      # @param auto_followup [Boolean] Discard if replied (requires send_at)
      # @param external_response_id [String] WhatsApp template ID
      # @param external_response_variables [Hash] WhatsApp template variables
      # @return [Missive::Object] The created draft
      # @raise [ArgumentError] If required parameters are missing or invalid
      #
      # @example Create basic email draft
      #   drafts.create(
      #     subject: "Hello",
      #     body: "World!",
      #     to_fields: [{address: "paul@acme.com"}],
      #     from_field: {name: "Philippe", address: "philippe@missiveapp.com"}
      #   )
      #
      # @example Create scheduled draft with attachments
      #   drafts.create(
      #     body: "Meeting notes attached",
      #     to_fields: [{address: "team@acme.com"}],
      #     from_field: {address: "sender@acme.com"},
      #     attachments: [{
      #       base64_data: "iVBORw0KGgoAAAANS...",
      #       filename: "notes.pdf"
      #     }],
      #     send_at: Time.now.to_i + 3600
      #   )
      def create(
        body:,
        to_fields:,
        from_field:,
        subject: nil,
        quote_previous_message: nil,
        cc_fields: nil,
        bcc_fields: nil,
        account: nil,
        attachments: nil,
        references: nil,
        conversation: nil,
        team: nil,
        force_team: nil,
        organization: nil,
        add_users: nil,
        add_assignees: nil,
        conversation_subject: nil,
        conversation_color: nil,
        add_shared_labels: nil,
        remove_shared_labels: nil,
        add_to_inbox: nil,
        add_to_team_inbox: nil,
        close: nil,
        send: nil,
        send_at: nil,
        auto_followup: nil,
        external_response_id: nil,
        external_response_variables: nil
      )
        # Validate required parameters
        validate_required_params(body: body, to_fields: to_fields, from_field: from_field)

        # Validate complex parameters
        validate_attachments(attachments) if attachments
        validate_scheduling(send: send, send_at: send_at, auto_followup: auto_followup)
        validate_conversation_params(references: references, conversation: conversation)
        validate_dependencies(
          organization: organization,
          add_users: add_users,
          add_assignees: add_assignees,
          team: team,
          add_to_team_inbox: add_to_team_inbox
        )

        # Build payload with all parameters
        payload = build_payload(
          body: body,
          to_fields: to_fields,
          from_field: from_field,
          subject: subject,
          quote_previous_message: quote_previous_message,
          cc_fields: cc_fields,
          bcc_fields: bcc_fields,
          account: account,
          attachments: attachments,
          references: references,
          conversation: conversation,
          team: team,
          force_team: force_team,
          organization: organization,
          add_users: add_users,
          add_assignees: add_assignees,
          conversation_subject: conversation_subject,
          conversation_color: conversation_color,
          add_shared_labels: add_shared_labels,
          remove_shared_labels: remove_shared_labels,
          add_to_inbox: add_to_inbox,
          add_to_team_inbox: add_to_team_inbox,
          close: close,
          send: send,
          send_at: send_at,
          auto_followup: auto_followup,
          external_response_id: external_response_id,
          external_response_variables: external_response_variables
        )

        ActiveSupport::Notifications.instrument("missive.drafts.create", payload: payload) do
          response = @client.connection.request(:post, CREATE, body: payload)

          # Handle nil or empty response
          raise Missive::Error, "Draft not created" if response.nil? || response.empty?

          # API returns {drafts: single_draft} structure
          # Extract the draft from the response
          draft_data = response[:drafts] || response["drafts"]

          # If no drafts key, assume the response itself is the draft data
          if draft_data.nil?
            raise Missive::Error, "Draft not created" if response.is_a?(String)

            draft_data = response

          end

          Missive::Object.new(draft_data, @client)
        end
      end

      # Send a message immediately (convenience wrapper for create with send: true)
      #
      # @param args [Hash] Same parameters as #create
      # @return [Missive::Object] The sent message
      def send_message(**args)
        create(**args, send: true)
      end

      # Schedule a message for later sending
      #
      # @param send_at [Integer] Unix timestamp for when to send
      # @param auto_followup [Boolean] Cancel if conversation receives reply
      # @param args [Hash] Same parameters as #create
      # @return [Missive::Object] The scheduled draft
      def schedule_message(send_at:, auto_followup: false, **args)
        create(**args, send_at: send_at, auto_followup: auto_followup)
      end

      private

      attr_reader :client

      def validate_required_params(body:, to_fields:, from_field:)
        raise ArgumentError, "body is required" if body.nil? || body.empty?
        raise ArgumentError, "to_fields is required" if to_fields.nil? || to_fields.empty?
        raise ArgumentError, "from_field is required" if from_field.nil? || from_field.empty?
      end

      def validate_attachments(attachments)
        return unless attachments

        raise ArgumentError, "attachments must be an array" unless attachments.is_a?(Array)

        if attachments.length > MAX_ATTACHMENTS
          raise ArgumentError, "Maximum #{MAX_ATTACHMENTS} attachments allowed, got #{attachments.length}"
        end

        attachments.each_with_index do |attachment, index|
          raise ArgumentError, "Attachment #{index} must be a hash" unless attachment.is_a?(Hash)

          unless attachment[:base64_data] || attachment["base64_data"]
            raise ArgumentError, "Attachment #{index} must include base64_data"
          end

          raise ArgumentError, "Attachment #{index} must include filename" unless attachment[:filename] || attachment["filename"]
        end
      end

      def validate_scheduling(send:, send_at:, auto_followup:)
        raise ArgumentError, "Cannot use both send: true and send_at (mutually exclusive)" if send && send_at

        raise ArgumentError, "auto_followup requires send_at to be specified" if auto_followup && !send_at

        return unless send_at && send_at <= Time.now.to_i

        raise ArgumentError, "send_at must be in the future"
      end

      def validate_conversation_params(references:, conversation:)
        raise ArgumentError, "Cannot pass both references and conversation (mutually exclusive)" if references && conversation

        return unless references && !references.is_a?(Array)

        raise ArgumentError, "references must be an array"
      end

      def validate_dependencies(organization:, add_users:, add_assignees:, team:, add_to_team_inbox:)
        if (add_users || add_assignees) && !organization
          raise ArgumentError, "organization is required when using add_users or add_assignees"
        end

        return unless add_to_team_inbox && !team

        raise ArgumentError, "team is required when using add_to_team_inbox"
      end

      def build_payload(**params)
        # Filter out nil values and build the drafts payload
        draft_params = params.compact

        {
          drafts: draft_params
        }
      end
    end
  end
end
