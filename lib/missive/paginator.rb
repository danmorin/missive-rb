# frozen_string_literal: true

require "active_support"
require "json"

module Missive
  module Paginator
    extend self

    def each_page(path:, client:, params: {}, **opts)
      page_number = 1
      max_pages = opts[:max_pages]
      max_offset = opts[:max_offset]
      sleep_interval = opts.fetch(:sleep_interval, 0)
      current_params = params.dup
      pagination_style = nil

      loop do
        break if max_pages && page_number > max_pages

        url = build_url(path, current_params)
        ActiveSupport::Notifications.instrument("missive.paginator.page", page_number: page_number, url: url)

        parsed_response = client.connection.request(:get, url)

        # Detect pagination style on first response
        if pagination_style.nil?
          pagination_style = if parsed_response.key?(:offset) && parsed_response.key?(:limit)
                               :offset
                             else
                               :until
                             end
        end

        yield parsed_response

        # Handle pagination based on detected style
        if pagination_style == :offset
          current_offset = parsed_response[:offset] || 0
          limit = parsed_response[:limit] || 50
          # Try to find the data array in common locations
          data_array = parsed_response[:data] ||
                       parsed_response[:contacts] ||
                       parsed_response[:contact_books] ||
                       parsed_response[:contact_groups] ||
                       []
          data_count = data_array.size

          # Stop if we have a max_offset and we've reached it
          break if max_offset && current_offset >= max_offset

          # Stop if we got fewer items than the limit (last page)
          break if data_count < limit

          # Calculate next offset
          next_offset = current_offset + limit

          # If max_offset is set, don't exceed it
          next_offset = [next_offset, max_offset].min if max_offset

          current_params = current_params.merge(offset: next_offset)
        else
          # Original until-based pagination
          break unless parsed_response.dig(:next, :until)

          current_params = current_params.merge(until: parsed_response.dig(:next, :until))
        end

        page_number += 1
        sleep(sleep_interval) if sleep_interval.positive?
      end
    end

    def each_item(path:, client:, params: {}, **opts)
      items_yielded = 0
      max_items = opts[:max_items]
      data_key = opts[:data_key] || :data

      each_page(path: path, params: params, client: client, **opts) do |page|
        data_array = page[data_key] || []

        data_array.each do |item|
          break if max_items && items_yielded >= max_items

          yield item
          items_yielded += 1
        end

        break if max_items && items_yielded >= max_items
      end
    end

    private

    def build_url(path, params)
      return path if params.empty?

      query_string = params.map { |k, v| "#{k}=#{v}" }.join("&")
      "#{path}?#{query_string}"
    end
  end
end
