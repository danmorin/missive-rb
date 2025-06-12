# frozen_string_literal: true

module Missive
  module Resources
    # Handles all task-related API operations
    #
    # @example Creating a standalone task
    #   task = client.tasks.create(
    #     title: "Follow up with client",
    #     team: "team-123",
    #     organization: "org-123"
    #   )
    #
    # @example Creating a subtask
    #   subtask = client.tasks.create(
    #     title: "Review document",
    #     subtask: true,
    #     conversation: "conv-123"
    #   )
    #
    # @example Updating a task
    #   updated = client.tasks.update(
    #     id: "task-123",
    #     state: "done",
    #     title: "Updated title"
    #   )
    class Tasks
      CREATE = "/tasks"
      UPDATE = "/tasks/%<id>s"

      # Valid task states
      VALID_STATES = %w[todo done].freeze

      # Allowed fields for task updates per Missive API
      ALLOWED_UPDATE_FIELDS = %w[
        title description state assignees team due_at
      ].freeze

      attr_reader :client

      # @!attribute [r] client
      #   @return [Missive::Client] The API client instance

      # Initialize a new Tasks resource
      # @param client [Missive::Client] The API client instance
      def initialize(client)
        @client = client
      end

      # Create a new task
      # @param title [String] Task title (required, max 1000 chars)
      # @param organization [String, nil] Organization ID for task scope
      # @param state [String, Symbol] Task state (:todo or :done, default: :todo)
      # @param attrs [Hash] Additional task attributes
      # @option attrs [String] :description Task description
      # @option attrs [Array<String>] :assignees Array of user IDs (for standalone tasks)
      # @option attrs [String] :team Team ID (for standalone tasks)
      # @option attrs [String] :due_at ISO8601 due date
      # @option attrs [Boolean] :subtask Whether this is a subtask
      # @option attrs [String] :conversation Conversation ID (for subtasks)
      # @option attrs [Array<String>] :references Reference IDs (for subtasks)
      # @return [Missive::Object] The created task object
      # @raise [ArgumentError] When validation fails
      # @example Create standalone task assigned to team
      #   client.tasks.create(title: "Review proposal", team: "team-123")
      # @example Create subtask for conversation
      #   client.tasks.create(title: "Follow up", subtask: true, conversation: "conv-123")
      def create(title:, organization: nil, state: :todo, **attrs)
        # Validate title presence and length
        raise ArgumentError, "title cannot be blank" if title.nil? || title.strip.empty?
        raise ArgumentError, "title cannot exceed 1000 characters" if title.length > 1000

        # Validate state
        state_str = state.to_s
        raise ArgumentError, "state must be one of: #{VALID_STATES.join(", ")}" unless VALID_STATES.include?(state_str)

        # Build task data
        task_data = { title: title, state: state_str }
        task_data[:organization] = organization if organization
        task_data.merge!(attrs)

        # Validate business rules
        validate_task_creation_rules(task_data)

        body = { tasks: task_data }

        ActiveSupport::Notifications.instrument("missive.tasks.create", body: body) do
          response = client.connection.request(:post, CREATE, body: body)

          # API returns { tasks: task_data }
          task_data = response[:tasks]
          raise Missive::ServerError, "Task creation failed" unless task_data

          Missive::Object.new(task_data, client)
        end
      end

      # Update an existing task
      # @param id [String] Task ID (required)
      # @param attrs [Hash] Task attributes to update
      # @option attrs [String] :title Task title
      # @option attrs [String] :description Task description
      # @option attrs [String, Symbol] :state Task state (:todo or :done)
      # @option attrs [Array<String>] :assignees Array of user IDs
      # @option attrs [String] :team Team ID
      # @option attrs [String] :due_at ISO8601 due date
      # @return [Missive::Object] The updated task object
      # @raise [ArgumentError] When validation fails
      # @example Update task state
      #   client.tasks.update(id: "task-123", state: "done")
      # @example Update title and description
      #   client.tasks.update(id: "task-123", title: "New title", description: "Updated description")
      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def update(id:, **attrs)
        raise ArgumentError, "id cannot be blank" if id.nil? || id.strip.empty?
        raise ArgumentError, "no attributes provided for update" if attrs.empty?

        # Filter to allowed fields only
        filtered_attrs = attrs.select { |key, _| ALLOWED_UPDATE_FIELDS.include?(key.to_s) }
        raise ArgumentError, "no valid attributes provided for update" if filtered_attrs.empty?

        # Validate state if provided
        if filtered_attrs[:state] || filtered_attrs["state"]
          state_val = (filtered_attrs[:state] || filtered_attrs["state"]).to_s
          raise ArgumentError, "state must be one of: #{VALID_STATES.join(", ")}" unless VALID_STATES.include?(state_val)

          # Ensure we store as string
          filtered_attrs[:state] = state_val
          filtered_attrs.delete("state")
        end

        # Validate title length if provided
        title_val = filtered_attrs[:title] || filtered_attrs["title"]
        raise ArgumentError, "title cannot exceed 1000 characters" if title_val && title_val.length > 1000

        path = format(UPDATE, id: id)
        body = { tasks: filtered_attrs }

        ActiveSupport::Notifications.instrument("missive.tasks.update", body: body, id: id) do
          response = client.connection.request(:patch, path, body: body)

          # API returns { tasks: task_data }
          task_data = response[:tasks]
          raise Missive::ServerError, "Task update failed" unless task_data

          Missive::Object.new(task_data, client)
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      private

      # Validate task creation business rules
      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def validate_task_creation_rules(task_data)
        is_subtask = task_data[:subtask] || task_data["subtask"]

        if is_subtask
          # For subtasks, require either conversation or references
          has_conversation = task_data[:conversation] || task_data["conversation"]
          has_references = task_data[:references] || task_data["references"]

          raise ArgumentError, "subtasks require either 'conversation' or 'references'" unless has_conversation || has_references
        else
          # For standalone tasks, require either team or assignees
          has_team = task_data[:team] || task_data["team"]
          has_assignees = (task_data[:assignees] || task_data["assignees"])&.any?

          raise ArgumentError, "standalone tasks require either 'team' or 'assignees'" unless has_team || has_assignees
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    end
  end
end
