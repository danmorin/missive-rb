# frozen_string_literal: true

module Missive
  module Resources
    # Resource for managing responses
    class Responses
      # Path constants
      LIST = "/responses"
      GET = "/responses/%<id>s"

      # @param client [Missive::Client] The API client instance
      def initialize(client)
        @client = client
      end

      # List responses with pagination
      #
      # @param limit [Integer] Number of responses per page (max: 200)
      # @param offset [Integer] Starting position for pagination
      # @param organization [String, nil] Organization ID to filter by
      # @return [Array<Missive::Object>] Array of response objects for the current page
      def list(limit: 50, offset: 0, organization: nil)
        raise ArgumentError, "limit cannot exceed 200" if limit > 200

        params = { limit: limit, offset: offset }
        params[:organization] = organization if organization

        ActiveSupport::Notifications.instrument("missive.responses.list", params: params) do
          response = @client.connection.request(:get, LIST, params: params)
          
          # Return array of Missive::Object instances
          (response[:responses] || []).map { |resp| Missive::Object.new(resp, @client) }
        end
      end

      # Iterate through all responses with automatic pagination
      #
      # @param params [Hash] Query parameters including limit, offset, and organization
      # @yield [Missive::Object] Each response object
      # @return [Enumerator] If no block given
      def each_item(**params)
        params[:limit] ||= 50
        raise ArgumentError, "limit cannot exceed 200" if params[:limit] > 200

        Missive::Paginator.each_item(
          path: LIST,
          client: @client,
          params: params,
          data_key: :responses
        ) do |item|
          yield Missive::Object.new(item, @client)
        end
      end

      # Get a specific response by ID
      #
      # @param id [String] The response ID
      # @return [Missive::Object] The response object
      # @raise [Missive::NotFoundError] When response is not found
      def get(id:)
        path = format(GET, id: id)

        ActiveSupport::Notifications.instrument("missive.responses.get", id: id) do
          response = @client.connection.request(:get, path)
          Missive::Object.new(response, @client)
        end
      end

      private

      attr_reader :client
    end
  end
end
