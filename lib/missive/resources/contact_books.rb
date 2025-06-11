# frozen_string_literal: true

module Missive
  module Resources
    # Handles contact book listing operations
    #
    # @example List contact books
    #   books = client.contact_books.list(limit: 50)
    #   books.each { |book| puts book.name }
    #
    # @example Iterate through all contact books
    #   client.contact_books.each_item do |book|
    #     puts "#{book.name} (#{book.id})"
    #   end
    class ContactBooks
      LIST = "/contact_books"

      # @!attribute [r] client
      #   @return [Missive::Client] The API client instance
      attr_reader :client

      # Initialize a new ContactBooks resource
      # @param client [Missive::Client] The API client instance
      def initialize(client)
        @client = client
      end

      # List contact books with pagination support
      # @param limit [Integer] Number of books per page (max: 200)
      # @param offset [Integer] Starting position for pagination
      # @param params [Hash] Additional query parameters
      # @return [Array<Missive::Object>] Array of contact book objects
      # @raise [ArgumentError] When limit exceeds 200
      # @example List first 50 contact books
      #   books = client.contact_books.list
      # @example List with custom limit
      #   books = client.contact_books.list(limit: 100, offset: 50)
      def list(limit: 50, offset: 0, **params)
        # Enforce limit cap
        raise ArgumentError, "limit cannot exceed 200" if limit > 200

        merged_params = { limit: limit, offset: offset }.merge(params)

        ActiveSupport::Notifications.instrument("missive.contact_books.list", params: merged_params) do
          response = client.connection.request(:get, LIST, params: merged_params)

          # Return array of Missive::Object instances
          (response[:contact_books] || []).map { |book| Missive::Object.new(book, client) }
        end
      end

      # Iterate through all contact books with automatic pagination
      # @param params [Hash] Query parameters
      # @option params [Integer] :limit Number of books per page (max: 200)
      # @yield [Missive::Object] Each contact book object
      # @return [Enumerator] If no block given
      # @raise [ArgumentError] When limit exceeds 200
      # @example Iterate through all books
      #   client.contact_books.each_item do |book|
      #     puts "#{book.name}: #{book.contacts_count} contacts"
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
          data_key: :contact_books
        ) do |item|
          # Convert each item to a Missive::Object
          yield Missive::Object.new(item, client)
        end
      end
    end
  end
end
