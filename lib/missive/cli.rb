# frozen_string_literal: true

require "thor"
require "yaml"
require "json"
require "date"

# rubocop:disable Rails/Output, Rails/Exit

module Missive
  # Command Line Interface for Missive API
  #
  # Provides CLI access to Missive API functionality with configuration
  # loaded from ~/.missive.yml
  class CLI < Thor
    private

    # Load configuration from ~/.missive.yml
    # @return [Hash] Configuration hash
    def load_config
      config_file = File.expand_path("~/.missive.yml")
      return {} unless File.exist?(config_file)

      YAML.load_file(config_file) || {}
    rescue StandardError => e
      puts "Error loading config from #{config_file}: #{e.message}"
      {}
    end

    # Get a configured Missive client
    # @return [Missive::Client] API client instance
    def client
      @client ||= begin
        config = load_config
        api_token = determine_api_token(config)

        unless api_token
          puts "Error: No API token found. Use --token flag, set MISSIVE_API_TOKEN environment variable, " \
               "or create ~/.missive.yml with api_token"
          exit 1
        end

        Missive::Client.new(api_token: api_token)
      end
    end

    # Determine API token from various sources in priority order
    def determine_api_token(config)
      # Check for command line token option first
      return options[:token] if options && options[:token]

      # Then config file
      return config["api_token"] if config["api_token"]

      # Finally environment variable
      ENV.fetch("MISSIVE_API_TOKEN", nil)
    end

    # Teams subcommand
    class Teams < Thor
      desc "list", "List teams"
      option :limit, type: :numeric, default: 10, desc: "Number of teams to return"
      option :organization, type: :string, desc: "Organization ID to filter by"
      def list
        teams = parent.send(:client).teams.list(
          limit: options[:limit],
          organization: options[:organization]
        ).compact

        if teams.empty?
          puts "No teams found"
        else
          puts JSON.pretty_generate(teams.map(&:to_h))
        end
      rescue StandardError => e
        puts "Error: #{e.message}"
        exit 1
      end

      private

      def parent
        @parent ||= CLI.new
      end
    end

    # Tasks subcommand
    class Tasks < Thor
      desc "create", "Create a new task"
      option :title, type: :string, required: true, desc: "Task title"
      option :team, type: :string, desc: "Team ID for the task"
      option :organization, type: :string, desc: "Organization ID for the task"
      option :state, type: :string, default: "todo", desc: "Task state (todo or done)"
      option :description, type: :string, desc: "Task description"
      option :assignees, type: :array, desc: "Array of assignee user IDs"
      option :due_at, type: :string, desc: "Due date (ISO8601 format)"
      def create
        task = parent.send(:client).tasks.create(**task_attributes)
        puts task.id
      rescue StandardError => e
        puts "Error: #{e.message}"
        exit 1
      end

      desc "update", "Update an existing task's fields"
      option :id, type: :string, required: true, desc: "Task ID to update"
      option :title, type: :string, desc: "New title for the task"
      option :state, type: :string, desc: "New state for the task (todo or done)"
      option :description, type: :string, desc: "New description"
      option :assignees, type: :array, desc: "New list of assignee user IDs"
      option :team, type: :string, desc: "New team ID (for standalone tasks)"
      # rubocop:disable Metrics/AbcSize
      def update
        task_id = options[:id]
        # Build attributes hash for update (only include provided options)
        attrs = {}
        attrs[:title] = options[:title] if options.key?(:title)
        attrs[:state] = options[:state] if options.key?(:state)
        attrs[:description] = options[:description] if options.key?(:description)
        attrs[:assignees] = options[:assignees] if options.key?(:assignees)
        attrs[:team] = options[:team] if options.key?(:team)

        if attrs.empty?
          puts "Error: no update attributes provided. See --help for options."
          exit 1
        end

        updated = parent.send(:client).tasks.update(id: task_id, **attrs)
        puts updated.id
      rescue StandardError => e
        puts "Error: #{e.message}"
        exit 1
      end
      # rubocop:enable Metrics/AbcSize

      private

      # rubocop:disable Metrics/AbcSize
      def task_attributes
        attrs = {
          title: options[:title],
          state: options[:state]
        }
        attrs[:team] = options[:team] if options[:team]
        attrs[:organization] = options[:organization] if options[:organization]
        attrs[:description] = options[:description] if options[:description]
        attrs[:assignees] = options[:assignees] if options[:assignees]
        attrs[:due_at] = options[:due_at] if options[:due_at]
        attrs
      end
      # rubocop:enable Metrics/AbcSize

      def parent
        @parent ||= CLI.new
      end
    end

    # Hooks subcommand
    class Hooks < Thor
      desc "create", "Create a new webhook"
      option :type, type: :string, required: true, desc: "Webhook event type (e.g., new_comment, incoming_email, etc.)"
      option :url,  type: :string, required: true, desc: "Target URL to receive the webhook"
      option :mailbox, type: :string, desc: "Optional mailbox ID filter for the webhook"
      option :organization, type: :string, desc: "Optional organization ID filter"
      option :teams, type: :array, desc: "Optional team IDs (space-separated if multiple) to filter"
      option :users, type: :array, desc: "Optional user IDs to filter"
      # rubocop:disable Metrics/AbcSize
      def create
        # Build attributes hash for create (only include provided options)
        attrs = {
          type: options[:type],
          url: options[:url]
        }
        attrs[:mailbox] = options[:mailbox] if options[:mailbox]
        attrs[:organization] = options[:organization] if options[:organization]
        attrs[:teams] = options[:teams] if options[:teams]
        attrs[:users] = options[:users] if options[:users]

        hook = parent.send(:client).hooks.create(**attrs)
        puts hook.id
      rescue StandardError => e
        puts "Error: #{e.message}"
        exit 1
      end
      # rubocop:enable Metrics/AbcSize

      desc "delete HOOK_ID", "Delete a webhook"
      def delete(hook_id)
        parent.send(:client).hooks.delete(id: hook_id)
        puts "deleted"
      rescue StandardError => e
        puts "Error: #{e.message}"
        exit 1
      end

      private

      def parent
        @parent ||= CLI.new
      end
    end

    # Contacts subcommand
    class Contacts < Thor
      desc "sync", "Stream contacts via paginator and output as JSON"
      option :since, type: :string, desc: "Modified since date (YYYY-MM-DD)"
      option :limit, type: :numeric, default: 50, desc: "Number of contacts per page"
      def sync
        modified_since = parse_date(options[:since]) if options[:since]

        parent.send(:client).contacts.each_item(
          limit: options[:limit],
          modified_since: modified_since
        ) do |contact|
          puts JSON.generate(contact.to_h)
        end
      rescue StandardError => e
        puts "Error: #{e.message}"
        exit 1
      end

      private

      def parse_date(date_string)
        Date.parse(date_string).to_time.to_i
      rescue ArgumentError
        puts "Error: Invalid date format. Use YYYY-MM-DD"
        exit 1
      end

      def parent
        @parent ||= CLI.new
      end
    end

    # Conversations subcommand
    class Conversations < Thor
      desc "export", "Export conversation, messages and comments to JSON file"
      option :id, type: :string, required: true, desc: "Conversation ID"
      option :file, type: :string, required: true, desc: "Output file path"
      def export
        conversation = parent.send(:client).conversations.get(options[:id])
        messages = collect_messages(options[:id])
        comments = collect_comments(options[:id])

        export_data = {
          conversation: conversation.to_h,
          messages: messages,
          comments: comments
        }

        File.write(options[:file], JSON.pretty_generate(export_data))
        puts "Exported conversation #{options[:id]} to #{options[:file]}"
      rescue StandardError => e
        puts "Error: #{e.message}"
        exit 1
      end

      private

      def collect_messages(conversation_id)
        messages = []
        parent.send(:client).conversations.each_message(conversation_id) do |message|
          messages << message.to_h
        end
        messages
      end

      def collect_comments(conversation_id)
        comments = []
        parent.send(:client).conversations.each_comment(conversation_id) do |comment|
          comments << comment.to_h
        end
        comments
      end

      def parent
        @parent ||= CLI.new
      end
    end

    # Analytics subcommand
    class Analytics < Thor
      desc "report", "Create analytics report and optionally wait for completion"
      option :type, type: :string, required: true, desc: "Report type (e.g., email_volume)"
      option :wait, type: :boolean, default: false, desc: "Wait for report completion"
      option :organization, type: :string, desc: "Organization ID"
      option :start_time, type: :string, desc: "Start time (ISO8601 format)"
      option :end_time, type: :string, desc: "End time (ISO8601 format)"
      option :timeout, type: :numeric, default: 300, desc: "Timeout in seconds when waiting"
      # rubocop:disable Metrics/AbcSize
      def report
        report_params = build_report_params
        report = parent.send(:client).analytics.create_report(**report_params)

        if options[:wait]
          completed_report = parent.send(:client).analytics.wait_for_report(
            report.id,
            timeout: options[:timeout]
          )
          puts completed_report.data.url if completed_report.data&.url
        elsif report.data&.url
          puts report.data.url
        end
      rescue StandardError => e
        puts "Error: #{e.message}"
        exit 1
      end
      # rubocop:enable Metrics/AbcSize

      private

      def build_report_params
        params = {
          reports: {
            type: options[:type]
          }
        }

        params[:organization] = options[:organization] if options[:organization]
        params[:reports][:start_time] = options[:start_time] if options[:start_time]
        params[:reports][:end_time] = options[:end_time] if options[:end_time]

        params
      end

      def parent
        @parent ||= CLI.new
      end
    end

    # Users subcommand
    class Users < Thor
      desc "list", "List users"
      option :limit, type: :numeric, default: 10, desc: "Number of users to return"
      option :organization, type: :string, desc: "Organization ID to filter by"
      def list
        users = parent.send(:client).users.list(
          limit: options[:limit],
          organization: options[:organization]
        ).compact

        if users.empty?
          puts "No users found"
        else
          puts JSON.pretty_generate(users.map(&:to_h))
        end
      rescue StandardError => e
        puts "Error: #{e.message}"
        exit 1
      end

      private

      def parent
        @parent ||= CLI.new
      end
    end
  end

  # Register subcommands after classes are defined
  class CLI < Thor
    class_option :token, type: :string, desc: "API token (overrides config file and environment)"

    def self.exit_on_failure?
      true
    end

    desc "teams SUBCOMMAND", "Manage teams"
    subcommand "teams", Teams

    desc "tasks SUBCOMMAND", "Manage tasks"
    subcommand "tasks", Tasks

    desc "hooks SUBCOMMAND", "Manage webhooks"
    subcommand "hooks", Hooks

    desc "contacts SUBCOMMAND", "Manage contacts"
    subcommand "contacts", Contacts

    desc "conversations SUBCOMMAND", "Manage conversations"
    subcommand "conversations", Conversations

    desc "analytics SUBCOMMAND", "Manage analytics"
    subcommand "analytics", Analytics

    desc "users SUBCOMMAND", "Manage users"
    subcommand "users", Users
  end
end

# rubocop:enable Rails/Output, Rails/Exit
