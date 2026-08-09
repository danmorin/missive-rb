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
      UPDATE = "/conversations/%<ids>s"
      MESSAGES = "/conversations/%<id>s/messages"
      COMMENTS = "/conversations/%<id>s/comments"
      POSTS = "/conversations/%<id>s/posts"
      MERGE = "/conversations/%<id>s/merge"

      # Attrs on PATCH /conversations that Missive requires `organization`
      # alongside (endpoints.md §Update conversations).
      ORGANIZATION_DEPENDENT_ATTRS = %i[
        add_users add_assignees remove_assignees add_shared_labels
      ].freeze

      # Presence of any of these in an action's opts means the caller wants a
      # visible trace in the thread, so the action is routed through
      # POST /posts instead of the silent PATCH endpoint.
      POST_CONTENT_KEYS = %i[
        text markdown attachments notification username username_icon
        conversation_icon
      ].freeze

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

      # Update one or more conversations without creating a post
      #
      # Wraps `PATCH /v1/conversations/:id[,:id2,...]` (shipped by Missive
      # 2026-06-19). This is the endpoint to use for silent state changes —
      # close, reopen, assign, label, recolor, rename, move. The older
      # POST /posts route is still valid but always leaves a visible comment
      # in the thread and, per Missive's docs, a post reopens a closed
      # conversation unless `reopen: true` is set on it.
      #
      # Missive requires the request body to carry one object per ID in the
      # URL, each repeating its own `id`. This method applies the same attrs
      # to every ID; pass `conversations:` to {#update_each} for per-ID attrs.
      #
      # @param ids [String, Array<String>] One or more conversation IDs
      # @param attrs [Hash] Attributes to set. Supported by the API:
      #   :subject, :color, :conversation_color, :organization, :team,
      #   :force_team, :add_users, :add_assignees, :remove_assignees,
      #   :add_shared_labels, :remove_shared_labels, :add_to_inbox,
      #   :add_to_team_inbox, :close, :reopen
      # @return [Array<Missive::Object>] The updated conversation objects
      # @raise [ArgumentError] When ids are missing/duplicated or attrs are empty
      # @example Close a conversation silently
      #   client.conversations.update(ids: "conv-123", close: true)
      # @example Close and label a batch in one call
      #   client.conversations.update(
      #     ids: %w[conv-1 conv-2 conv-3],
      #     close: true,
      #     add_shared_labels: ["lbl-1"],
      #     organization: "org-1"
      #   )
      def update(ids:, **attrs)
        id_list = normalize_ids(ids)
        raise ArgumentError, "attrs cannot be empty" if attrs.empty?

        update_each(conversations: id_list.map { |id| attrs.merge(id: id) })
      end

      # Update several conversations with per-conversation attributes
      #
      # Lower-level sibling of {#update} for when each conversation needs a
      # different payload. Each hash must carry its own `:id`.
      #
      # @param conversations [Array<Hash>] One hash per conversation, each with :id
      # @return [Array<Missive::Object>] The updated conversation objects
      # @raise [ArgumentError] When the array is empty, an entry lacks :id,
      #   IDs are duplicated, or an org-dependent attr is set without :organization
      # @example
      #   client.conversations.update_each(conversations: [
      #     { id: "conv-1", close: true },
      #     { id: "conv-2", subject: "Renamed" }
      #   ])
      def update_each(conversations:)
        raise ArgumentError, "conversations must be an array" unless conversations.is_a?(Array)
        raise ArgumentError, "conversations cannot be empty" if conversations.empty?

        entries = conversations.map { |entry| normalize_update_entry(entry) }
        id_list = entries.map { |entry| entry[:id] }
        validate_unique_ids!(id_list)

        path = format(UPDATE, ids: id_list.join(","))
        body = { conversations: entries }

        ActiveSupport::Notifications.instrument("missive.conversations.update", ids: id_list) do
          response = client.connection.request(:patch, path, body: body)
          updated = response[:conversations] || response["conversations"] || []
          updated.map { |conversation| Missive::Object.new(conversation, client) }
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

      # Get posts for a specific conversation
      #
      # Posts are integration-driven entries on a conversation — created via
      # `POST /v1/posts` (e.g. action posts from {#close}, {#reopen},
      # {#add_labels}, {#assign}; or notes from automation/webhooks). Distinct
      # from {#comments}, which are inline user-typed comments on messages.
      #
      # @param conversation_id [String] The conversation ID
      # @param limit [Integer] Number of posts per page (max: 10)
      # @param until_cursor [String] Pagination cursor for fetching older posts
      # @return [Array<Missive::Object>] Array of post objects for the current page
      # @raise [ArgumentError] When limit exceeds 10
      # @example Get posts on a conversation
      #   posts = client.conversations.posts(conversation_id: "conv-123")
      def posts(conversation_id:, limit: 10, until_cursor: nil)
        # Mirror the gem's documented messages/comments cap (10/page).
        raise ArgumentError, "limit cannot exceed 10" if limit > 10

        path = format(POSTS, id: conversation_id)
        params = { limit: limit }
        params[:until] = until_cursor if until_cursor

        ActiveSupport::Notifications.instrument("missive.conversations.posts", conversation_id: conversation_id,
                                                                                params: params) do
          response = client.connection.request(:get, path, params: params)

          (response[:posts] || []).map { |post| Missive::Object.new(post, client) }
        end
      end

      # Iterate through all posts for a conversation with automatic pagination
      #
      # @param conversation_id [String] The conversation ID
      # @param limit [Integer] Number of posts per page (max: 10)
      # @yield [Missive::Object] Each post object
      # @return [Enumerator] If no block given
      # @raise [ArgumentError] When limit exceeds 10
      # @example Iterate through all posts
      #   client.conversations.each_post(conversation_id: "conv-123") do |post|
      #     puts post.text
      #   end
      def each_post(conversation_id:, limit: 10, **params)
        raise ArgumentError, "limit cannot exceed 10" if limit > 10

        path = format(POSTS, id: conversation_id)
        merged_params = { limit: limit }.merge(params)

        Missive::Paginator.each_item(
          path: path,
          client: client,
          params: merged_params,
          data_key: :posts
        ) do |item|
          yield Missive::Object.new(item, client)
        end
      end

      # Close a conversation
      #
      # Marks the conversation as closed (removed from inbox) for everyone
      # with access. Reversible via {#reopen}.
      #
      # Routes through `PATCH /conversations/:id` by default, which closes
      # silently. If you pass post content (`:text`, `:markdown`,
      # `:attachments`, `:notification`) or `via: :post`, the older
      # POST /posts route is used instead so the close leaves a visible
      # comment explaining itself.
      #
      # @param id [String] The conversation ID
      # @param opts [Hash] Optional pass-through attrs (e.g. :text to attach
      #   a closing comment, :notification, :organization, :via)
      # @return [Array<Missive::Object>, Missive::Object] Updated conversations
      #   (PATCH route) or the created post (posts route)
      # @raise [ArgumentError] When id is missing
      # @example Close a conversation silently
      #   client.conversations.close(id: "conv-123")
      # @example Close with a visible closing comment
      #   client.conversations.close(id: "conv-123", text: "Resolved.")
      def close(id:, **opts)
        validate_id!(id)
        conversation_action(
          id: id,
          patch_attrs: { close: true },
          post_attrs: { close: true },
          defaults: { title: "Conversation closed", text: "Conversation closed via API" },
          opts: opts
        )
      end

      # Reopen a closed conversation
      #
      # Returns the conversation to the inbox for everyone with access.
      #
      # On POST /posts, `reopen` means the OPPOSITE thing — Missive documents
      # it as "prevents closed conversations from reopening when creating a
      # post". Since a post already reopens a closed conversation by default,
      # the posts route here sends a plain post with no reopen attr at all;
      # only the PATCH route sends `reopen: true`. Setting that flag on a post
      # (as this gem did through v0.2.7) kept the conversation closed, which
      # is exactly backwards.
      #
      # @param id [String] The conversation ID
      # @param opts [Hash] Optional pass-through attrs
      # @return [Array<Missive::Object>, Missive::Object] Updated conversations
      #   (PATCH route) or the created post (posts route)
      # @raise [ArgumentError] When id is missing
      # @example
      #   client.conversations.reopen(id: "conv-123")
      def reopen(id:, **opts)
        validate_id!(id)
        conversation_action(
          id: id,
          patch_attrs: { reopen: true },
          post_attrs: {},
          defaults: { title: "Conversation reopened", text: "Conversation reopened via API" },
          opts: opts
        )
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
        conversation_action(
          id: id,
          patch_attrs: { add_shared_labels: labels },
          post_attrs: { add_shared_labels: labels },
          defaults: { title: "Labels added", text: "Labels added via API" },
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
        conversation_action(
          id: id,
          patch_attrs: { remove_shared_labels: labels },
          post_attrs: { remove_shared_labels: labels },
          defaults: { title: "Labels removed", text: "Labels removed via API" },
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
        conversation_action(
          id: id,
          patch_attrs: { add_assignees: users },
          post_attrs: { add_assignees: users },
          defaults: { title: "Assignees updated", text: "Assignees updated via API" },
          opts: opts.merge(organization: organization)
        )
      end

      # Remove assignees from a conversation
      #
      # @param id [String] The conversation ID
      # @param users [Array<String>] Non-empty array of user IDs
      # @param organization [String] Organization ID (required by API)
      # @param opts [Hash] Optional pass-through attrs
      # @return [Array<Missive::Object>, Missive::Object] Updated conversations
      #   (PATCH route) or the created post (posts route)
      # @raise [ArgumentError] When required args are missing/empty
      # @example
      #   client.conversations.unassign(
      #     id: "conv-123",
      #     users: ["user-1"],
      #     organization: "org-1"
      #   )
      def unassign(id:, users:, organization:, **opts)
        validate_id!(id)
        validate_id_array!(users, name: "users")
        validate_present!(organization, name: "organization")
        conversation_action(
          id: id,
          patch_attrs: { remove_assignees: users },
          post_attrs: { remove_assignees: users },
          defaults: { title: "Assignees updated", text: "Assignees removed via API" },
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
        conversation_action(
          id: id,
          patch_attrs: { add_to_inbox: true },
          post_attrs: { add_to_inbox: true },
          defaults: { title: "Moved to inbox", text: "Moved to inbox via API" },
          opts: opts
        )
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
        conversation_action(
          id: id,
          patch_attrs: { add_to_team_inbox: true },
          post_attrs: { add_to_team_inbox: true },
          defaults: { title: "Moved to team inbox", text: "Moved to team inbox via API" },
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

      # Internal: pick the route for a conversation state change and dispatch.
      #
      # `PATCH /conversations/:id` (Missive, 2026-06-19) changes state
      # silently. `POST /posts` changes state AND drops a comment in the
      # thread — which also means it surfaces the conversation for everyone
      # who had it closed. PATCH is therefore the default; the posts route is
      # taken only when the caller asked for a visible trace, either by
      # supplying post content or by passing `via: :post`.
      #
      # @param id [String] Conversation ID
      # @param patch_attrs [Hash] Attrs to send on the PATCH route
      # @param post_attrs [Hash] Attrs to send on the posts route (differs from
      #   patch_attrs for :reopen — see {#reopen})
      # @param defaults [Hash] :title and :text defaults for the posts route
      # @param opts [Hash] Caller-supplied additional attrs, plus optional :via
      # @return [Array<Missive::Object>, Missive::Object] Updated conversations
      #   or the created post
      # @raise [ArgumentError] On an unknown :via, or post content with via: :patch
      def conversation_action(id:, patch_attrs:, post_attrs:, defaults:, opts: {})
        opts = opts.transform_keys(&:to_sym)
        via = opts.delete(:via)
        content_keys = opts.keys & POST_CONTENT_KEYS

        return update(ids: id, **patch_attrs, **opts) if resolve_route(via, content_keys) == :patch

        post_action(id: id, attrs: post_attrs, defaults: defaults, opts: opts)
      end

      # Internal: :patch unless the caller asked for a visible trace.
      def resolve_route(via, content_keys)
        case (via || :auto).to_sym
        when :auto
          content_keys.empty? ? :patch : :post
        when :post
          :post
        when :patch
          raise_post_only_keys!(content_keys)
          :patch
        else
          raise ArgumentError, "via must be one of :auto, :patch, :post (got #{via.inspect})"
        end
      end

      def raise_post_only_keys!(content_keys)
        return if content_keys.empty?

        raise ArgumentError,
              "#{content_keys.join(", ")} only apply to the posts route — drop them or pass via: :post"
      end

      # Internal: dispatch a single conversation-action POST /posts call
      # with the right action attrs, organization passthrough, and sensible
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
      # @param attrs [Hash] Action attrs (e.g. {close: true})
      # @param defaults [Hash] :title for the notification and :text for the body,
      #   each used only when the caller supplied no equivalent
      # @param opts [Hash] Caller-supplied additional attrs
      # @return [Missive::Object] The created post
      def post_action(id:, attrs:, defaults:, opts: {})
        merged = opts.dup
        merged[:notification] ||= { title: defaults[:title], body: DEFAULT_ACTION_NOTIFICATION_BODY }
        merged[:text] = defaults[:text] unless merged[:text] || merged[:markdown] || merged[:attachments]
        client.posts.create(conversation: id, **attrs, **merged)
      end

      # Internal: coerce a String/Array of conversation IDs to a validated Array
      def normalize_ids(ids)
        list = ids.is_a?(Array) ? ids : [ids]
        raise ArgumentError, "ids cannot be empty" if list.empty?

        list.each_with_index do |id, index|
          raise ArgumentError, "ids[#{index}] is required" if id.nil? || id.to_s.strip.empty?
        end

        list.map { |id| id.to_s.strip }
      end

      # Internal: validate and normalize one entry of an update_each payload
      def normalize_update_entry(entry)
        raise ArgumentError, "each conversation must be a Hash" unless entry.is_a?(Hash)

        normalized = entry.transform_keys(&:to_sym)
        id = normalized[:id]
        raise ArgumentError, "each conversation requires an id" if id.nil? || id.to_s.strip.empty?

        attrs = normalized.except(:id)
        raise ArgumentError, "conversation #{id} has no attributes to update" if attrs.empty?

        validate_organization_dependencies!(attrs.keys, normalized[:organization])

        normalized.merge(id: id.to_s.strip)
      end

      # Internal: Missive requires `organization` alongside the attrs that
      # reference org-scoped records (users, assignees, shared labels).
      def validate_organization_dependencies!(keys, organization)
        dependent = keys & ORGANIZATION_DEPENDENT_ATTRS
        return if dependent.empty?
        return unless organization.nil? || organization.to_s.strip.empty?

        raise ArgumentError, "organization is required when setting #{dependent.join(", ")}"
      end

      # Internal: Missive resolves merged conversation IDs server-side, so two
      # distinct IDs in one request can still collide. We can only catch the
      # exact-duplicate case, which the API rejects outright.
      def validate_unique_ids!(id_list)
        duplicates = id_list.tally.select { |_, count| count > 1 }.keys
        raise ArgumentError, "duplicate conversation ids: #{duplicates.join(", ")}" if duplicates.any?
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
