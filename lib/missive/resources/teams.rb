# frozen_string_literal: true

module Missive
  module Resources
    # Handles all team-related API operations
    #
    # @example Listing teams
    #   teams = client.teams.list(limit: 100)
    #
    # @example Iterating through all teams
    #   client.teams.each_item(organization: "org-123") do |team|
    #     puts team.name
    #   end
    class Teams
      LIST = "/teams"

      attr_reader :client

      # @!attribute [r] client
      #   @return [Missive::Client] The API client instance

      # Initialize a new Teams resource
      # @param client [Missive::Client] The API client instance
      def initialize(client)
        @client = client
      end

      # List teams with pagination support
      # @param limit [Integer] Number of teams per page (max: 200, default: 50)
      # @param offset [Integer] Starting position for pagination (default: 0)
      # @param organization [String, nil] Organization ID to filter teams
      # @return [Array<Missive::Object>] Array of team objects for the current page
      # @raise [ArgumentError] When limit exceeds 200
      # @example List teams with custom limit
      #   teams = client.teams.list(limit: 100, organization: "org-123")
      def list(limit: 50, offset: 0, organization: nil)
        # Enforce limit cap
        raise ArgumentError, "limit cannot exceed 200" if limit > 200

        params = { limit: limit, offset: offset }
        params[:organization] = organization if organization

        ActiveSupport::Notifications.instrument("missive.teams.list", params: params) do
          response = client.connection.request(:get, LIST, params: params)

          # Return array of Missive::Object instances
          (response[:teams] || []).map { |team| Missive::Object.new(team, client) }
        end
      end

      # Iterate through all teams with automatic pagination
      # @param params [Hash] Query parameters
      # @option params [Integer] :limit Number of teams per page (max: 200, default: 50)
      # @option params [String] :organization Organization ID to filter teams
      # @yield [Missive::Object] Each team object
      # @return [Enumerator] If no block given
      # @raise [ArgumentError] When limit exceeds 200
      # @example Iterate through all teams
      #   client.teams.each_item do |team|
      #     puts "Team: #{team.name}"
      #   end
      # @example Iterate with organization filter
      #   client.teams.each_item(organization: "org-123") do |team|
      #     puts team.name
      #   end
      def each_item(**params)
        # Default limit if not provided
        params[:limit] ||= 50

        # Enforce limit cap
        raise ArgumentError, "limit cannot exceed 200" if params[:limit] > 200

        Missive::Paginator.each_item(
          path: LIST,
          client: client,
          params: params,
          data_key: :teams
        ) do |item|
          # Convert each item to a Missive::Object
          yield Missive::Object.new(item, client)
        end
      end
    end
  end
end
