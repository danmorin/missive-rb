# frozen_string_literal: true

module Missive
  module Resources
    # Handles all user-related API operations
    #
    # @example Listing users
    #   users = client.users.list(limit: 100)
    #
    # @example Iterating through all users
    #   client.users.each_item(organization: "org-123") do |user|
    #     puts user.email
    #   end
    class Users
      LIST = "/users"

      attr_reader :client

      # @!attribute [r] client
      #   @return [Missive::Client] The API client instance

      # Initialize a new Users resource
      # @param client [Missive::Client] The API client instance
      def initialize(client)
        @client = client
      end

      # List users with pagination support
      # @param limit [Integer] Number of users per page (max: 200, default: 50)
      # @param offset [Integer] Starting position for pagination (default: 0)
      # @param organization [String, nil] Organization ID to filter users
      # @return [Array<Missive::Object>] Array of user objects for the current page
      # @raise [ArgumentError] When limit exceeds 200
      # @example List users with custom limit
      #   users = client.users.list(limit: 100, organization: "org-123")
      def list(limit: 50, offset: 0, organization: nil)
        # Enforce limit cap
        raise ArgumentError, "limit cannot exceed 200" if limit > 200

        params = { limit: limit, offset: offset }
        params[:organization] = organization if organization

        ActiveSupport::Notifications.instrument("missive.users.list", params: params) do
          response = client.connection.request(:get, LIST, params: params)

          # Return array of Missive::Object instances
          (response[:users] || []).map { |user| Missive::Object.new(user, client) }
        end
      end

      # Iterate through all users with automatic pagination
      # @param params [Hash] Query parameters
      # @option params [Integer] :limit Number of users per page (max: 200, default: 50)
      # @option params [String] :organization Organization ID to filter users
      # @yield [Missive::Object] Each user object
      # @return [Enumerator] If no block given
      # @raise [ArgumentError] When limit exceeds 200
      # @example Iterate through all users
      #   client.users.each_item do |user|
      #     puts "User: #{user.email}"
      #   end
      # @example Iterate with organization filter
      #   client.users.each_item(organization: "org-123") do |user|
      #     puts user.email
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
          data_key: :users
        ) do |item|
          # Convert each item to a Missive::Object
          yield Missive::Object.new(item, client)
        end
      end
    end
  end
end
