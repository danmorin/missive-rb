# frozen_string_literal: true

module Missive
  module Resources
    # Resource for managing shared labels
    class SharedLabels
      # Path constants
      CREATE = "/shared_labels"
      UPDATE = "/shared_labels/%<ids>s"
      LIST = "/shared_labels"

      # Color validation regex
      COLOR_REGEX = /^#(?:[0-9a-fA-F]{3}){1,2}$/
      VALID_COLOR_WORDS = %w[good warning danger].freeze

      # @param client [Missive::Client] The API client instance
      def initialize(client)
        @client = client
      end

      # Create shared labels
      #
      # @param labels [Array<Hash>] Array of label objects to create
      # @return [Array<Missive::Object>] Array of created label objects
      # @raise [ArgumentError] If labels are invalid
      def create(labels:)
        validate_labels_for_create(labels)

        payload = { shared_labels: labels }

        ActiveSupport::Notifications.instrument("missive.shared_labels.create", payload: payload) do
          response = @client.connection.request(:post, CREATE, body: payload)
          # Missive returns { shared_labels: [...created labels...] }; older code
          # used `Array(response)` which collapsed the envelope into a single
          # empty Missive::Object. Extract the inner array correctly.
          inner = response[:shared_labels] || response["shared_labels"] || []
          inner.map { |label| Missive::Object.new(label, @client) }
        end
      end

      # Update shared labels
      #
      # Missive's PATCH /v1/shared_labels/:ids endpoint accepts an array body
      # `{shared_labels: [{id: ..., name: ..., color: ..., parent: ...}, ...]}`.
      #
      # NOTE: `organization` is REQUIRED on create but FORBIDDEN on update —
      # Missive returns "Unpermitted parameters: organization" if you include
      # it in the update payload. The gem strips :organization from each
      # label hash to keep the call from 422-ing on a field the API rejects
      # for this verb.
      #
      # @param labels [Array<Hash>] Array of label objects to update (must include id)
      # @return [Array<Missive::Object>] Array of updated label objects
      # @raise [ArgumentError] If labels are invalid (missing id)
      def update(labels:)
        validate_labels_for_update(labels)
        sanitized = labels.map { |l| l.reject { |k, _| %i[organization].include?(k.to_sym) } }
        ids = sanitized.map { |label| label[:id] || label["id"] }.compact

        path = format(UPDATE, ids: ids.join(","))
        payload = { shared_labels: sanitized }

        ActiveSupport::Notifications.instrument("missive.shared_labels.update", payload: payload) do
          response = @client.connection.request(:patch, path, body: payload)
          inner = response[:shared_labels] || response["shared_labels"] || []
          inner.map { |label| Missive::Object.new(label, @client) }
        end
      end

      # List shared labels with pagination
      #
      # @param limit [Integer] Number of labels per page (max: 200)
      # @param offset [Integer] Starting position for pagination
      # @param organization [String, nil] Organization ID to filter by
      # @return [Array<Missive::Object>] Array of shared label objects for the current page
      def list(limit: 50, offset: 0, organization: nil)
        raise ArgumentError, "limit cannot exceed 200" if limit > 200

        params = { limit: limit, offset: offset }
        params[:organization] = organization if organization

        ActiveSupport::Notifications.instrument("missive.shared_labels.list", params: params) do
          response = @client.connection.request(:get, LIST, params: params)

          # Return array of Missive::Object instances
          (response[:shared_labels] || []).map { |label| Missive::Object.new(label, @client) }
        end
      end

      # Iterate through all shared labels with automatic pagination
      #
      # @param params [Hash] Query parameters including limit, offset, organization
      # @yield [Missive::Object] Each label object
      # @return [Enumerator] If no block given
      def each_item(**params)
        params[:limit] ||= 50
        raise ArgumentError, "limit cannot exceed 200" if params[:limit] > 200

        Missive::Paginator.each_item(
          path: LIST,
          client: @client,
          params: params,
          data_key: :shared_labels
        ) do |item|
          yield Missive::Object.new(item, @client)
        end
      end

      private

      attr_reader :client

      def validate_labels_for_create(labels)
        Array(labels).each do |label|
          name = label[:name] || label["name"]
          organization = label[:organization] || label["organization"]
          raise ArgumentError, "Each label must have a name" unless name
          raise ArgumentError, "Each label must have an organization" unless organization
          validate_color(label[:color] || label["color"]) if label[:color] || label["color"]
        end
      end

      # Update validation only requires id; Missive validates the rest of
      # the fields server-side (and rejects organization outright on PATCH).
      def validate_labels_for_update(labels)
        Array(labels).each do |label|
          id = label[:id] || label["id"]
          raise ArgumentError, "Each label must have an id for update" unless id
          validate_color(label[:color] || label["color"]) if label[:color] || label["color"]
        end
      end

      # Backwards-compat alias for any external callers that wrapped the
      # private API. New code should use the per-verb validators above.
      def validate_labels(labels)
        validate_labels_for_create(labels)
      end

      def validate_required_fields(label)
        name = label[:name] || label["name"]
        organization = label[:organization] || label["organization"]

        raise ArgumentError, "Each label must have a name" unless name
        raise ArgumentError, "Each label must have an organization" unless organization
      end

      def validate_color(color)
        return if color.match?(COLOR_REGEX) || VALID_COLOR_WORDS.include?(color)

        raise ArgumentError,
              "Invalid color: #{color}. Must be a hex color (#RGB or #RRGGBB) or one of: #{VALID_COLOR_WORDS.join(", ")}"
      end
    end
  end
end
