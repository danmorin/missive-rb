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

      loop do # rubocop:disable Metrics/BlockLength
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
        elsif parsed_response.dig(:next, :until)
          # Until-based pagination for conversations, messages, and comments
          # Check for explicit next cursor first (backward compatibility)
          next_until = parsed_response.dig(:next, :until)
          current_params = current_params.merge(until: next_until)
        else
          # Fall back to timestamp-based pagination for Missive API endpoints
          # Find data array in common locations for conversations/messages/comments
          data_array = parsed_response[:data] ||
                       parsed_response[:conversations] ||
                       parsed_response[:messages] ||
                       parsed_response[:comments] ||
                       []

          # Break if no data returned
          break if data_array.empty?

          limit = current_params[:limit] || 25

          # Break if we got fewer items than requested (last page)
          break if data_array.size < limit

          # Determine next cursor based on endpoint type
          next_until = if parsed_response[:messages] || parsed_response[:comments]
                         # Messages/comments use delivered_at timestamp from last item
                         data_array.last[:delivered_at]
                       else
                         # Conversations and other endpoints may use created_at or updated_at
                         data_array.last[:created_at] || data_array.last[:updated_at]
                       end

          # Break if no next cursor available
          break unless next_until

          # Break if all items have the same timestamp (boundary condition)
          timestamp_field = if parsed_response[:messages] || parsed_response[:comments]
                              :delivered_at
                            else
                              :created_at
                            end

          break if data_array.all? { |item| item[timestamp_field] == next_until }

          current_params = current_params.merge(until: next_until)
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
