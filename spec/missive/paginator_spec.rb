# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"
require_relative "../support/shared_examples/paginator_examples"

RSpec.describe Missive::Paginator do
  let(:client) { instance_double("Missive::Client") }
  let(:connection) { instance_double("Missive::Connection") }

  before do
    allow(client).to receive(:connection).and_return(connection)
  end

  shared_examples "a paginator" do |transcript|
    let(:path) { "/test" }
    let(:params) { {} }
    let(:pages) { transcript }

    before do
      pages.each_with_index do |page_data, index|
        url = if index == 0
                path
              else
                "#{path}?until=#{pages[index - 1][:next][:until]}"
              end

        allow(connection).to receive(:request).with(:get, url).and_return(page_data)
      end
    end

    describe ".each_page" do
      it "hits correct initial URL" do
        described_class.each_page(path: path, params: params, client: client) { |_page| break }
        expect(connection).to have_received(:request).with(:get, path)
      end

      it "continues until next.until missing" do
        page_count = 0
        described_class.each_page(path: path, params: params, client: client) do |_page|
          page_count += 1
        end
        expect(page_count).to eq(pages.length)
      end

      it "yields correct count of pages" do
        yielded_pages = []
        described_class.each_page(path: path, params: params, client: client) do |page|
          yielded_pages << page
        end
        expect(yielded_pages.length).to eq(pages.length)
      end

      it "honors max_pages" do
        max_pages = 1
        page_count = 0
        described_class.each_page(path: path, params: params, client: client, max_pages: max_pages) do |_page|
          page_count += 1
        end
        expect(page_count).to eq(max_pages)
      end

      it "emits missive.paginator.page notification" do
        notifications = []
        ActiveSupport::Notifications.subscribe("missive.paginator.page") do |_name, _start, _finish, _id, payload|
          notifications << payload
        end

        described_class.each_page(path: path, params: params, client: client) { |_page| break }

        expect(notifications).not_to be_empty
        expect(notifications.first).to include(page_number: 1, url: path)
      end

      it "respects sleep_interval" do
        allow(described_class).to receive(:sleep)
        described_class.each_page(path: path, params: params, client: client, sleep_interval: 0.1) { |_page| }
        expect(described_class).to have_received(:sleep).with(0.1).at_least(:once) if pages.length > 1
      end

      it "builds correct URL with params" do
        initial_params = { limit: 10 }
        allow(connection).to receive(:request).with(:get, "/test?limit=10").and_return(pages.first)

        described_class.each_page(path: path, params: initial_params, client: client) { |_page| break }
        expect(connection).to have_received(:request).with(:get, "/test?limit=10")
      end

      it "does not sleep when interval is zero" do
        allow(described_class).to receive(:sleep)
        described_class.each_page(path: path, params: params, client: client, sleep_interval: 0) { |_page| }
        expect(described_class).not_to have_received(:sleep)
      end

      it "does not sleep when interval is negative" do
        allow(described_class).to receive(:sleep)
        described_class.each_page(path: path, params: params, client: client, sleep_interval: -1) { |_page| }
        expect(described_class).not_to have_received(:sleep)
      end
    end

    describe ".each_item" do
      it "flattens data array and yields individual items" do
        items = []
        described_class.each_item(path: path, params: params, client: client) do |item|
          items << item
        end

        expected_items = pages.flat_map { |page| page[:data] || [] }
        expect(items).to eq(expected_items)
      end

      it "honors max_items" do
        max_items = 1
        items = []
        described_class.each_item(path: path, params: params, client: client, max_items: max_items) do |item|
          items << item
        end
        expect(items.length).to eq(max_items)
      end
    end
  end

  context "with single page transcript" do
    include_examples "a paginator", [
      {
        data: [
          { id: 1, name: "Item 1" },
          { id: 2, name: "Item 2" }
        ]
      }
    ]
  end

  context "with multi-page transcript" do
    include_examples "a paginator", [
      {
        data: [
          { id: 1, name: "Item 1" },
          { id: 2, name: "Item 2" }
        ],
        next: { until: "token1" }
      },
      {
        data: [
          { id: 3, name: "Item 3" },
          { id: 4, name: "Item 4" }
        ],
        next: { until: "token2" }
      },
      {
        data: [
          { id: 5, name: "Item 5" }
        ]
      }
    ]
  end

  context "with offset-based pagination" do
    let(:client) { instance_double("Missive::Client") }
    let(:connection) { instance_double("Missive::Connection") }

    before do
      allow(client).to receive(:connection).and_return(connection)
    end

    it_behaves_like "an offset paginator"

    context "with max_offset limit" do
      it "stops pagination when max_offset is reached" do
        page1 = { data: Array.new(200) { |i| { id: i } }, offset: 0, limit: 200 }
        page2 = { data: Array.new(200) { |i| { id: i + 200 } }, offset: 200, limit: 200 }
        page3 = { data: Array.new(100) { |i| { id: i + 300 } }, offset: 300, limit: 200 }

        allow(connection).to receive(:request).with(:get, "/contacts?limit=200").and_return(page1)
        allow(connection).to receive(:request).with(:get, "/contacts?limit=200&offset=200").and_return(page2)
        allow(connection).to receive(:request).with(:get, "/contacts?limit=200&offset=300").and_return(page3)

        items = []
        described_class.each_item(
          path: "/contacts",
          params: { limit: 200 },
          client: client,
          max_offset: 300
        ) do |item|
          items << item
        end

        expect(items.length).to eq(500)
        expect(connection).to have_received(:request).exactly(3).times
      end
    end
  end

  context "with enhanced until-based pagination for conversations/messages/comments" do
    let(:client) { instance_double("Missive::Client") }
    let(:connection) { instance_double("Missive::Connection") }

    before do
      allow(client).to receive(:connection).and_return(connection)
    end

    it "handles result sets exceeding limit and detects done condition" do
      # First page: limit=50, returns 75 items (exceeds limit), with different timestamps
      page1 = {
        conversations: Array.new(75) { |i| { id: i, created_at: "2024-01-01T10:#{i % 60}:00Z" } },
        next: { until: "2024-01-01T09:00:00Z" }
      }

      # Second page: limit=50, returns 25 items (less than limit - done condition)
      page2 = {
        conversations: Array.new(25) { |i| { id: i + 75, created_at: "2024-01-01T09:00:00Z" } }
      }

      allow(connection).to receive(:request).with(:get, "/conversations?limit=50").and_return(page1)
      allow(connection).to receive(:request).with(:get, "/conversations?limit=50&until=2024-01-01T09:00:00Z").and_return(page2)

      pages = []
      described_class.each_page(
        path: "/conversations",
        params: { limit: 50 },
        client: client
      ) do |page|
        pages << page
      end

      expect(pages.size).to eq(2)
      expect(pages[0][:conversations].size).to eq(75)  # First page exceeds limit
      expect(pages[1][:conversations].size).to eq(25)  # Second page less than limit

      # Verify correct requests were made
      expect(connection).to have_received(:request).with(:get, "/conversations?limit=50")
      expect(connection).to have_received(:request).with(:get, "/conversations?limit=50&until=2024-01-01T09:00:00Z")
    end

    it "stops when all items have same timestamp as until token" do
      # Single page where all items have the same timestamp as the until token
      page1 = {
        messages: Array.new(60) { |i| { id: i, created_at: "2024-01-01T10:00:00Z" } },
        next: { until: "2024-01-01T10:00:00Z" }
      }

      allow(connection).to receive(:request).with(:get, "/messages?limit=50").and_return(page1)

      pages = []
      described_class.each_page(
        path: "/messages",
        params: { limit: 50 },
        client: client
      ) do |page|
        pages << page
      end

      expect(pages.size).to eq(1)
      expect(pages[0][:messages].size).to eq(60)

      # Should only make one request since all items have same timestamp
      expect(connection).to have_received(:request).with(:get, "/messages?limit=50")
      expect(connection).not_to have_received(:request).with(:get, "/messages?limit=50&until=2024-01-01T10:00:00Z")
    end
  end
end
