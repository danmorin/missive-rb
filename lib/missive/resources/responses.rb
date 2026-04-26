# frozen_string_literal: true

module Missive
  module Resources
    # Resource for managing responses
    class Responses
      # Path constants
      LIST = "/responses"
      GET = "/responses/%<id>s"
      CREATE = "/responses"
      UPDATE = "/responses/%<id>s"
      DELETE = "/responses/%<id>s"

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

          # API returns {responses: [single_response]} structure even for GET by ID
          # Extract the first response from the array
          responses = response[:responses] || response["responses"] || []
          raise Missive::NotFoundError, "Response not found" if responses.empty?

          Missive::Object.new(responses.first, @client)
        end
      end

      # Create a response template
      #
      # @param name [String] Response template name (required)
      # @param body [String] HTML or text body for the response (required)
      # @param attrs [Hash] Additional attributes (e.g. :organization, :shared,
      #   :shared_with_team, :shared_label)
      # @return [Missive::Object] The created response
      # @raise [ArgumentError] If name or body are missing/blank
      # @example
      #   client.responses.create(
      #     name: "Hello",
      #     body: "<p>Thanks for reaching out!</p>",
      #     organization: "org-1"
      #   )
      def create(name:, body:, **attrs)
        raise ArgumentError, "name cannot be blank" if name.nil? || name.to_s.strip.empty?
        raise ArgumentError, "body cannot be blank" if body.nil? || body.to_s.strip.empty?

        payload = { responses: { name: name, body: body }.merge(attrs) }

        ActiveSupport::Notifications.instrument("missive.responses.create", payload: payload) do
          response = @client.connection.request(:post, CREATE, body: payload)
          response_data = response[:responses] || response["responses"]
          raise Missive::ServerError, "Response creation failed" if response_data.nil?

          # API may return either a single hash or a [single] array.
          response_data = response_data.is_a?(Array) ? response_data.first : response_data
          Missive::Object.new(response_data, @client)
        end
      end

      # Update a response template
      #
      # @param id [String] Response ID (required)
      # @param attrs [Hash] Attributes to update (e.g. :name, :body,
      #   :organization, :shared, :shared_with_team, :shared_label)
      # @return [Missive::Object] The updated response
      # @raise [ArgumentError] If id is missing or no attributes provided
      # @example
      #   client.responses.update(id: "resp-1", body: "<p>Updated.</p>")
      def update(id:, **attrs)
        raise ArgumentError, "id cannot be blank" if id.nil? || id.to_s.strip.empty?
        raise ArgumentError, "no attributes provided for update" if attrs.empty?

        path = format(UPDATE, id: id)
        payload = { responses: attrs }

        ActiveSupport::Notifications.instrument("missive.responses.update", id: id, payload: payload) do
          response = @client.connection.request(:patch, path, body: payload)
          response_data = response[:responses] || response["responses"]
          raise Missive::ServerError, "Response update failed" if response_data.nil?

          response_data = response_data.is_a?(Array) ? response_data.first : response_data
          Missive::Object.new(response_data, @client)
        end
      end

      # Delete a response template
      #
      # @param id [String] Response ID (required)
      # @return [Boolean] True on success
      # @raise [ArgumentError] If id is missing
      # @raise [Missive::NotFoundError] If response not found
      def delete(id:)
        raise ArgumentError, "id cannot be blank" if id.nil? || id.to_s.strip.empty?

        path = format(DELETE, id: id)

        ActiveSupport::Notifications.instrument("missive.responses.delete", id: id) do
          @client.connection.request(:delete, path)
          true
        end
      end

      private

      attr_reader :client
    end
  end
end
