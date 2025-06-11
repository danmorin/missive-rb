# frozen_string_literal: true

module Missive
  module Resources
    # Handles all contact-related API operations
    #
    # @example Creating a contact
    #   contact = client.contacts.create(
    #     contacts: {
    #       email: "john@example.com",
    #       first_name: "John",
    #       last_name: "Doe",
    #       contact_book: "book-id"
    #     }
    #   )
    #
    # @example Updating contacts
    #   updated = client.contacts.update(
    #     contact_hashes: [
    #       { id: "contact-1", first_name: "Jane" },
    #       { id: "contact-2", last_name: "Smith" }
    #     ]
    #   )
    #
    # @example Listing contacts
    #   contacts = client.contacts.list(
    #     contact_book: "book-id",
    #     limit: 50
    #   )
    #
    # @example Iterating through all contacts
    #   client.contacts.each_item(contact_book: "book-id") do |contact|
    #     puts contact.email
    #   end
    class Contacts
      CREATE = "/contacts"
      UPDATE = "/contacts/%<ids>s"
      LIST = "/contacts"
      GET = "/contacts/%<id>s"

      # Allowed fields for contact updates per Missive API
      ALLOWED_UPDATE_FIELDS = %w[
        id email first_name last_name
        phone_number notes company_name
        twitter_handle facebook_handle
        custom_fields contact_book
      ].freeze

      attr_reader :client

      # @!attribute [r] client
      #   @return [Missive::Client] The API client instance

      # Initialize a new Contacts resource
      # @param client [Missive::Client] The API client instance
      def initialize(client)
        @client = client
      end

      # Create one or more contacts
      # @param contacts [Hash, Array<Hash>] Contact data or array of contact data
      # @return [Array<Missive::Object>] Array of created contact objects
      # @raise [Missive::ServerError] When validation fails (e.g., missing contact_book)
      # @example Create a single contact
      #   client.contacts.create(contacts: { email: "test@example.com", contact_book: "book-id" })
      # @example Create multiple contacts
      #   client.contacts.create(contacts: [{ email: "test1@example.com" }, { email: "test2@example.com" }])
      def create(contacts:)
        contacts_array = contacts.is_a?(Array) ? contacts : [contacts]

        body = { contacts: contacts_array }

        ActiveSupport::Notifications.instrument("missive.contacts.create", body: body) do
          response = client.connection.request(:post, CREATE, body: body)

          # Return array of Missive::Object instances
          (response[:contacts] || []).map { |contact| Missive::Object.new(contact, client) }
        end
      end

      # Update one or more contacts
      # @param contact_hashes [Hash, Array<Hash>] Contact data with required 'id' field
      # @param skip_validation [Boolean] Whether to skip schema validation (default: false)
      # @return [Array<Missive::Object>] Array of updated contact objects
      # @raise [ArgumentError] When any contact is missing an 'id' field
      # @example Update a single contact
      #   client.contacts.update(contact_hashes: { id: "contact-123", first_name: "Jane" })
      # @example Update with custom fields
      #   client.contacts.update(
      #     contact_hashes: { id: "contact-123", custom_xyz: "value" },
      #     skip_validation: true
      #   )
      def update(contact_hashes:, skip_validation: false)
        contacts_array = contact_hashes.is_a?(Array) ? contact_hashes : [contact_hashes]

        # Extract ids and validate
        validated_contacts = contacts_array.map do |hash|
          raise ArgumentError, "Each contact must have an 'id' field" unless hash["id"] || hash[:id]

          # Strip keys outside schema unless skip_validation is true
          if skip_validation
            hash
          else
            hash.select { |key, _| ALLOWED_UPDATE_FIELDS.include?(key.to_s) }
          end
        end

        ids = validated_contacts.map { |hash| hash["id"] || hash[:id] }

        # Build URI with comma-joined ids
        path = format(UPDATE, ids: ids.join(","))

        body = { contacts: validated_contacts }

        ActiveSupport::Notifications.instrument("missive.contacts.update", body: body, path: path) do
          response = client.connection.request(:patch, path, body: body)

          # Return array of Missive::Object instances
          (response[:contacts] || []).map { |contact| Missive::Object.new(contact, client) }
        end
      end

      # List contacts with pagination support
      # @param limit [Integer] Number of contacts per page (max: 200)
      # @param offset [Integer] Starting position for pagination
      # @param params [Hash] Additional query parameters
      # @option params [String] :contact_book The contact book ID (often required)
      # @option params [Integer] :modified_since Unix timestamp to filter by modification date
      # @return [Array<Missive::Object>] Array of contact objects for the current page
      # @raise [ArgumentError] When limit exceeds 200 or modified_since is not numeric
      # @example List contacts from a book
      #   contacts = client.contacts.list(contact_book: "book-id", limit: 100)
      def list(limit: 50, offset: 0, **params)
        # Enforce limit cap
        raise ArgumentError, "limit cannot exceed 200" if limit > 200

        # Validate modified_since if provided
        if params[:modified_since] && !params[:modified_since].is_a?(Numeric)
          raise ArgumentError, "modified_since must be a numeric epoch timestamp"
        end

        merged_params = { limit: limit, offset: offset }.merge(params)

        ActiveSupport::Notifications.instrument("missive.contacts.list", params: merged_params) do
          response = client.connection.request(:get, LIST, params: merged_params)

          # Return array of Missive::Object instances
          (response[:contacts] || []).map { |contact| Missive::Object.new(contact, client) }
        end
      end

      # Iterate through all contacts with automatic pagination
      # @param params [Hash] Query parameters including required :contact_book
      # @option params [Integer] :limit Number of contacts per page (max: 200)
      # @yield [Missive::Object] Each contact object
      # @return [Enumerator] If no block given
      # @raise [ArgumentError] When limit exceeds 200
      # @example Iterate through all contacts
      #   client.contacts.each_item(contact_book: "book-id") do |contact|
      #     puts contact.email
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
          data_key: :contacts
        ) do |item|
          # Convert each item to a Missive::Object
          yield Missive::Object.new(item, client)
        end
      end

      # Get a specific contact by ID
      # @param id [String] The contact ID
      # @return [Missive::Object] The contact object
      # @raise [Missive::NotFoundError] When contact is not found
      # @example Get a contact
      #   contact = client.contacts.get(id: "contact-123")
      #   puts contact.email
      def get(id:)
        path = format(GET, id: id)

        ActiveSupport::Notifications.instrument("missive.contacts.get", id: id) do
          response = client.connection.request(:get, path)
          # API returns { contacts: [contact] }, so we need to unwrap it
          contact_data = response[:contacts]&.first
          raise Missive::NotFoundError, "Contact not found" unless contact_data

          Missive::Object.new(contact_data, client)
        end
      end
    end
  end
end
