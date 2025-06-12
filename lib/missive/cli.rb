# frozen_string_literal: true

require "thor"
require "yaml"
require "json"

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
        api_token = config["api_token"] || ENV.fetch("MISSIVE_API_TOKEN", nil)

        unless api_token
          puts "Error: No API token found. Set MISSIVE_API_TOKEN environment variable or create ~/.missive.yml with api_token"
          exit 1
        end

        Missive::Client.new(api_token: api_token)
      end
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
  end

  # Register subcommands after classes are defined
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "teams SUBCOMMAND", "Manage teams"
    subcommand "teams", Teams

    desc "tasks SUBCOMMAND", "Manage tasks"
    subcommand "tasks", Tasks

    desc "hooks SUBCOMMAND", "Manage webhooks"
    subcommand "hooks", Hooks
  end
end

# rubocop:enable Rails/Output, Rails/Exit
