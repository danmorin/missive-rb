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
      MERGE = "/conversations/%<id>s/merge"

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

          # API returns {conversations: [single_conversation]} structure even for GET by ID
          # Extract the first conversation from the array
          conversations = response[:conversations] || response["conversations"] || []
          raise Missive::NotFoundError, "Conversation not found" if conversations.empty?

          Missive::Object.new(conversations.first, client)
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

      # Close a conversation
      #
      # Marks the conversation as closed (removed from inbox). Reversible
      # via {#reopen}. Implemented via POST /posts since Missive's REST
      # API exposes conversation state mutations through posts rather
      # than a dedicated PATCH endpoint.
      #
      # @param id [String] The conversation ID
      # @param opts [Hash] Optional pass-through attrs (e.g. :text to attach
      #   a closing comment, :notification, :organization)
      # @return [Missive::Object] The created post
      # @raise [ArgumentError] When id is missing
      # @example Close a conversation
      #   client.conversations.close(id: "conv-123")
      # @example Close with a closing comment
      #   client.conversations.close(id: "conv-123", text: "Resolved.")
      def close(id:, **opts)
        validate_id!(id)
        post_action(id: id, action: :close, default_title: "Conversation closed", default_text: "Conversation closed via API", opts: opts)
      end

      # Reopen a closed conversation
      #
      # Returns the conversation to the inbox.
      #
      # @param id [String] The conversation ID
      # @param opts [Hash] Optional pass-through attrs
      # @return [Missive::Object] The created post
      # @raise [ArgumentError] When id is missing
      # @example
      #   client.conversations.reopen(id: "conv-123")
      def reopen(id:, **opts)
        validate_id!(id)
        post_action(id: id, action: :reopen, default_title: "Conversation reopened", default_text: "Conversation reopened via API", opts: opts)
      end

      # Add shared labels to a conversation
      #
      # Missive requires `organization` whenever `add_shared_labels` is set
      # on a post. The gem enforces this at the API boundary.
      #
      # @param id [String] The conversation ID
      # @param labels [Array<String>] Non-empty array of shared label IDs
      # @param organization [String] Organization ID (required by API)
      # @param opts [Hash] Optional pass-through attrs
      # @return [Missive::Object] The created post
      # @raise [ArgumentError] When id, labels, or organization are missing/empty
      # @example
      #   client.conversations.add_labels(
      #     id: "conv-123",
      #     labels: ["lbl-1", "lbl-2"],
      #     organization: "org-1"
      #   )
      def add_labels(id:, labels:, organization:, **opts)
        validate_id!(id)
        validate_id_array!(labels, name: "labels")
        validate_present!(organization, name: "organization")
        post_action(
          id: id,
          action: :add_shared_labels,
          action_value: labels,
          default_title: "Labels added",
          default_text: "Labels added via API",
          opts: opts.merge(organization: organization)
        )
      end

      # Remove shared labels from a conversation
      #
      # Missive requires `organization` whenever `remove_shared_labels` is set
      # on a post. The gem enforces this at the API boundary.
      #
      # @param id [String] The conversation ID
      # @param labels [Array<String>] Non-empty array of shared label IDs
      # @param organization [String] Organization ID (required by API)
      # @param opts [Hash] Optional pass-through attrs
      # @return [Missive::Object] The created post
      # @raise [ArgumentError] When id, labels, or organization are missing/empty
      # @example
      #   client.conversations.remove_labels(
      #     id: "conv-123",
      #     labels: ["lbl-1"],
      #     organization: "org-1"
      #   )
      def remove_labels(id:, labels:, organization:, **opts)
        validate_id!(id)
        validate_id_array!(labels, name: "labels")
        validate_present!(organization, name: "organization")
        post_action(
          id: id,
          action: :remove_shared_labels,
          action_value: labels,
          default_title: "Labels removed",
          default_text: "Labels removed via API",
          opts: opts.merge(organization: organization)
        )
      end

      # Assign users to a conversation
      #
      # Adds the given users as assignees. Existing assignees are preserved.
      # Missive requires `organization` whenever assignees are added.
      #
      # @param id [String] The conversation ID
      # @param users [Array<String>] Non-empty array of user IDs
      # @param organization [String] Organization ID (required by API)
      # @param opts [Hash] Optional pass-through attrs
      # @return [Missive::Object] The created post
      # @raise [ArgumentError] When required args are missing/empty
      # @example
      #   client.conversations.assign(
      #     id: "conv-123",
      #     users: ["user-1"],
      #     organization: "org-1"
      #   )
      def assign(id:, users:, organization:, **opts)
        validate_id!(id)
        validate_id_array!(users, name: "users")
        validate_present!(organization, name: "organization")
        post_action(
          id: id,
          action: :add_assignees,
          action_value: users,
          default_title: "Assignees updated",
          default_text: "Assignees updated via API",
          opts: opts.merge(organization: organization)
        )
      end

      # Move a conversation to the inbox
      #
      # @param id [String] The conversation ID
      # @param opts [Hash] Optional pass-through attrs
      # @return [Missive::Object] The created post
      # @raise [ArgumentError] When id is missing
      # @example
      #   client.conversations.add_to_inbox(id: "conv-123")
      def add_to_inbox(id:, **opts)
        validate_id!(id)
        post_action(id: id, action: :add_to_inbox, default_title: "Moved to inbox", default_text: "Moved to inbox via API", opts: opts)
      end

      # Move a conversation to a team inbox
      #
      # @param id [String] The conversation ID
      # @param team [String] Team ID (required by API)
      # @param opts [Hash] Optional pass-through attrs
      # @return [Missive::Object] The created post
      # @raise [ArgumentError] When required args are missing/empty
      # @example
      #   client.conversations.add_to_team_inbox(id: "conv-123", team: "team-1")
      def add_to_team_inbox(id:, team:, **opts)
        validate_id!(id)
        validate_present!(team, name: "team")
        post_action(
          id: id,
          action: :add_to_team_inbox,
          default_title: "Moved to team inbox",
          default_text: "Moved to team inbox via API",
          opts: opts.merge(team: team)
        )
      end

      # Merge a conversation into another
      #
      # The conversation identified by `id` is merged into `target`. Per
      # Missive's API: "the returned conversation `id` can differ from
      # `target`" — Missive may swap source/target to preserve the
      # higher-traffic conversation.
      #
      # @param id [String] The source conversation ID (path param)
      # @param target [String] The destination conversation ID (body param)
      # @param subject [String, nil] Optional new subject for the merged conversation
      # @return [Missive::Object] The resulting (merged) conversation
      # @raise [ArgumentError] When id/target are missing or identical
      # @example
      #   client.conversations.merge(id: "src-123", target: "dst-456")
      # @example With a new subject
      #   client.conversations.merge(id: "src-123", target: "dst-456", subject: "Combined thread")
      def merge(id:, target:, subject: nil)
        validate_id!(id)
        validate_present!(target, name: "target")
        raise ArgumentError, "id and target must differ" if id == target

        path = format(MERGE, id: id)
        body = { target: target }
        body[:subject] = subject if subject

        ActiveSupport::Notifications.instrument("missive.conversations.merge", id: id, target: target) do
          response = client.connection.request(:post, path, body: body)
          convs = response[:conversations] || response["conversations"]
          raise Missive::ServerError, "Merge failed" if convs.nil? || (convs.respond_to?(:empty?) && convs.empty?)

          conv_data = convs.is_a?(Array) ? convs.first : convs
          Missive::Object.new(conv_data, client)
        end
      end

      private

      # Default notification body shared across action methods. Missive
      # requires `notification: {title, body}` on every POST /posts call,
      # even when the post only carries conversation-action attrs (close,
      # reopen, label/assignee changes). Callers can override by passing
      # their own `notification:` in `**opts`.
      DEFAULT_ACTION_NOTIFICATION_BODY = "via Missive API"

      # Internal: dispatch a single conversation-action POST /posts call
      # with the right action attr, organization passthrough, and sensible
      # defaults for the two fields Missive's API requires on every post:
      #
      #   1. `notification: {title, body}` — required on every POST /v1/posts.
      #   2. `text` / `markdown` / `attachments` — required content. Missive's
      #      API rejects metadata-only posts with
      #      "Validation failed: text, markdown or attachments needed".
      #
      # Caller-supplied values in `opts` always win — pass `text:`, `markdown:`,
      # `attachments:`, or `notification:` to override the defaults.
      #
      # @param id [String] Conversation ID
      # @param action [Symbol] Action attr key (e.g. :close, :add_shared_labels)
      # @param action_value [Object] Action attr value (defaults to true for booleans)
      # @param default_title [String] Default notification title if caller omits one
      # @param default_text [String] Default text body if caller didn't supply text/markdown/attachments
      # @param opts [Hash] Caller-supplied additional attrs
      # @return [Missive::Object] The created post
      def post_action(id:, action:, default_title:, default_text:, action_value: true, opts: {})
        merged = opts.dup
        merged[:notification] ||= { title: default_title, body: DEFAULT_ACTION_NOTIFICATION_BODY }
        unless merged[:text] || merged[:markdown] || merged[:attachments]
          merged[:text] = default_text
        end
        client.posts.create(conversation: id, action => action_value, **merged)
      end

      # Validate param combinations for list method
      # Fail fast on unsupported param combos per Missive API docs
      def validate_list_params?(_params)
        # This is a placeholder for validation logic based on Missive API docs
        # The actual validation would depend on the specific restrictions
        # mentioned in the API documentation
        true
      end

      def validate_id!(id)
        validate_present!(id, name: "id")
      end

      def validate_present!(value, name:)
        return unless value.nil? || value.to_s.strip.empty?

        raise ArgumentError, "#{name} is required"
      end

      def validate_id_array!(arr, name:)
        raise ArgumentError, "#{name} must be an array" unless arr.is_a?(Array)
        raise ArgumentError, "#{name} cannot be empty" if arr.empty?

        arr.each do |entry|
          raise ArgumentError, "#{name} entries must be non-blank strings" if entry.nil? || entry.to_s.strip.empty?
        end
      end
    end
  end
end
