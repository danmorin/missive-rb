# frozen_string_literal: true

module Missive
  module Resources
    # Resource for managing organizations
    class Organizations
      # Path constants
      LIST = "/organizations"

      # @param client [Missive::Client] The API client instance
      def initialize(client)
        @client = client
      end

      # List organizations with pagination
      #
      # @param limit [Integer] Number of organizations per page (max: 200)
      # @param offset [Integer] Starting position for pagination
      # @return [Array<Missive::Object>] Array of organization objects for the current page
      def list(limit: 50, offset: 0)
        raise ArgumentError, "limit cannot exceed 200" if limit > 200

        params = { limit: limit, offset: offset }

        ActiveSupport::Notifications.instrument("missive.organizations.list", params: params) do
          response = @client.connection.request(:get, LIST, params: params)
          
          # Return array of Missive::Object instances
          (response[:organizations] || []).map { |org| Missive::Object.new(org, @client) }
        end
      end

      # Iterate through all organizations with automatic pagination
      #
      # @param params [Hash] Query parameters including limit and offset
      # @yield [Missive::Object] Each organization object
      # @return [Enumerator] If no block given
      def each_item(**params)
        params[:limit] ||= 50
        raise ArgumentError, "limit cannot exceed 200" if params[:limit] > 200

        Missive::Paginator.each_item(
          path: LIST,
          client: @client,
          params: params,
          data_key: :organizations
        ) do |item|
          yield Missive::Object.new(item, @client)
        end
      end

      private

      attr_reader :client
    end
  end
end
