# frozen_string_literal: true

require "active_support"
require "json"

module Missive
  module Paginator
    extend self

    def each_page(path:, client:, params: {}, **opts)
      page_number = 1
      max_pages = opts[:max_pages]
      sleep_interval = opts.fetch(:sleep_interval, 0)
      current_params = params.dup

      loop do
        break if max_pages && page_number > max_pages

        url = build_url(path, current_params)
        ActiveSupport::Notifications.instrument("missive.paginator.page", page_number: page_number, url: url)

        parsed_response = client.connection.request(:get, url)

        yield parsed_response

        break unless parsed_response.dig("next", "until")

        current_params = current_params.merge(until: parsed_response.dig("next", "until"))
        page_number += 1

        sleep(sleep_interval) if sleep_interval.positive?
      end
    end

    def each_item(path:, client:, params: {}, **opts)
      items_yielded = 0
      max_items = opts[:max_items]

      each_page(path: path, params: params, client: client, **opts) do |page|
        data_array = page["data"] || []

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
