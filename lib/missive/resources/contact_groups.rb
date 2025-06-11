# frozen_string_literal: true

module Missive
  module Resources
    # Handles contact group and organization listing operations
    #
    # @example List groups in a contact book
    #   groups = client.contact_groups.list(
    #     contact_book: "book-id",
    #     kind: "group"
    #   )
    #
    # @example List organizations
    #   orgs = client.contact_groups.list(
    #     contact_book: "book-id",
    #     kind: "organization"
    #   )
    #
    # @example Iterate through all groups
    #   client.contact_groups.each_item(
    #     contact_book: "book-id",
    #     kind: "group"
    #   ) do |group|
    #     puts group.name
    #   end
    class ContactGroups
      LIST = "/contact_groups"
      VALID_KINDS = %w[group organization].freeze

      # @!attribute [r] client
      #   @return [Missive::Client] The API client instance
      attr_reader :client

      # Initialize a new ContactGroups resource
      # @param client [Missive::Client] The API client instance
      def initialize(client)
        @client = client
      end

      # List contact groups or organizations
      # @param contact_book [String] The contact book ID (required)
      # @param kind [String] Either 'group' or 'organization' (required)
      # @param limit [Integer] Number of items per page (max: 200)
      # @param offset [Integer] Starting position for pagination
      # @param params [Hash] Additional query parameters
      # @return [Array<Missive::Object>] Array of contact group objects
      # @raise [ArgumentError] When required params missing or invalid
      # @example List groups
      #   groups = client.contact_groups.list(
      #     contact_book: "book-id",
      #     kind: "group"
      #   )
      def list(contact_book:, kind:, limit: 50, offset: 0, **params)
        # Validate required parameters
        raise ArgumentError, "contact_book is required" if contact_book.nil? || contact_book.empty?
        raise ArgumentError, "kind is required" if kind.nil? || kind.empty?
        raise ArgumentError, "kind must be 'group' or 'organization'" unless VALID_KINDS.include?(kind)

        # Enforce limit cap
        raise ArgumentError, "limit cannot exceed 200" if limit > 200

        merged_params = {
          contact_book: contact_book,
          kind: kind,
          limit: limit,
          offset: offset
        }.merge(params)

        ActiveSupport::Notifications.instrument("missive.contact_groups.list", params: merged_params) do
          response = client.connection.request(:get, LIST, params: merged_params)

          # Return array of Missive::Object instances
          (response[:contact_groups] || []).map { |group| Missive::Object.new(group, client) }
        end
      end

      # Iterate through all contact groups with automatic pagination
      # @param params [Hash] Query parameters (must include :contact_book and :kind)
      # @option params [String] :contact_book The contact book ID (required)
      # @option params [String] :kind Either 'group' or 'organization' (required)
      # @option params [Integer] :limit Number of items per page (max: 200)
      # @yield [Missive::Object] Each contact group object
      # @return [Enumerator] If no block given
      # @raise [ArgumentError] When required params missing or invalid
      # @example Iterate through all groups
      #   client.contact_groups.each_item(
      #     contact_book: "book-id",
      #     kind: "group"
      #   ) do |group|
      #     puts "#{group.name}: #{group.contacts_count} members"
      #   end
      def each_item(**params)
        # Validate required parameters
        raise ArgumentError, "contact_book is required" unless params[:contact_book]
        raise ArgumentError, "kind is required" unless params[:kind]
        raise ArgumentError, "kind must be 'group' or 'organization'" unless VALID_KINDS.include?(params[:kind])

        # Default limit if not provided
        params[:limit] ||= 50

        # Enforce limit cap
        raise ArgumentError, "limit cannot exceed 200" if params[:limit] > 200

        Missive::Paginator.each_item(
          path: LIST,
          client: client,
          params: params,
          data_key: :contact_groups
        ) do |item|
          # Convert each item to a Missive::Object
          yield Missive::Object.new(item, client)
        end
      end
    end
  end
end
