# frozen_string_literal: true

require "spec_helper"

RSpec.describe Missive::Resources::ContactGroups do
  let(:client) { instance_double("Missive::Client") }
  let(:connection) { instance_double("Missive::Connection") }
  let(:contact_groups) { described_class.new(client) }
  let(:contact_book_id) { "book_123" }
  subject { contact_groups }

  before do
    allow(client).to receive(:connection).and_return(connection)
  end

  describe "#initialize" do
    it "stores the client" do
      expect(contact_groups.client).to eq(client)
    end
  end

  describe "#list" do
    let(:response) do
      {
        contact_groups: [
          { id: "group_1", name: "Marketing Team", kind: "group" },
          { id: "group_2", name: "Sales Team", kind: "group" }
        ],
        offset: 0,
        limit: 50
      }
    end
    let(:list_path) { "/contact_groups" }
    let(:required_list_params) { { contact_book: contact_book_id, kind: "group" } }

    it "sends GET request with default parameters" do
      expect(connection).to receive(:request).with(
        :get,
        "/contact_groups",
        params: { contact_book: contact_book_id, kind: "group", limit: 50, offset: 0 }
      ).and_return(response)

      contact_groups.list(contact_book: contact_book_id, kind: "group")
    end

    it "raises ArgumentError when limit exceeds 200" do
      expect do
        contact_groups.list(contact_book: contact_book_id, kind: "group", limit: 201)
      end.to raise_error(ArgumentError, "limit cannot exceed 200")
    end

    it "raises ArgumentError when contact_book is nil" do
      expect do
        contact_groups.list(contact_book: nil, kind: "group")
      end.to raise_error(ArgumentError, "contact_book is required")
    end

    it "raises ArgumentError when contact_book is empty" do
      expect do
        contact_groups.list(contact_book: "", kind: "group")
      end.to raise_error(ArgumentError, "contact_book is required")
    end

    it "raises ArgumentError when kind is nil" do
      expect do
        contact_groups.list(contact_book: contact_book_id, kind: nil)
      end.to raise_error(ArgumentError, "kind is required")
    end

    it "raises ArgumentError when kind is empty" do
      expect do
        contact_groups.list(contact_book: contact_book_id, kind: "")
      end.to raise_error(ArgumentError, "kind is required")
    end

    it "raises ArgumentError when kind is invalid" do
      expect do
        contact_groups.list(contact_book: contact_book_id, kind: "invalid")
      end.to raise_error(ArgumentError, "kind must be 'group' or 'organization'")
    end

    it "accepts 'group' as valid kind" do
      allow(connection).to receive(:request).and_return(response)
      expect do
        contact_groups.list(contact_book: contact_book_id, kind: "group")
      end.not_to raise_error
    end

    it "accepts 'organization' as valid kind" do
      allow(connection).to receive(:request).and_return(response)
      expect do
        contact_groups.list(contact_book: contact_book_id, kind: "organization")
      end.not_to raise_error
    end
  end

  describe "#each_item" do
    let(:first_page) do
      {
        contact_groups: [
          { id: "group_1", name: "Marketing", kind: "group" },
          { id: "group_2", name: "Sales", kind: "group" }
        ],
        offset: 0,
        limit: 2
      }
    end
    let(:data_key) { :contact_groups }
    let(:required_params) { { contact_book: contact_book_id, kind: "group" } }

    it "raises ArgumentError when limit exceeds 200" do
      expect do
        contact_groups.each_item(contact_book: contact_book_id, kind: "group", limit: 201) { |_| } # rubocop:disable Lint/EmptyBlock
      end.to raise_error(ArgumentError, "limit cannot exceed 200")
    end

    it "calls Paginator.each_item with correct parameters" do
      expect(Missive::Paginator).to receive(:each_item).with(
        path: "/contact_groups",
        client: client,
        params: { contact_book: contact_book_id, kind: "group", limit: 50 },
        data_key: :contact_groups
      )

      contact_groups.each_item(contact_book: contact_book_id, kind: "group") { |_| } # rubocop:disable Lint/EmptyBlock
    end

    let(:page2) do
      {
        contact_groups: [
          { id: "group_3", name: "Support", kind: "group" }
        ],
        offset: 2,
        limit: 2
      }
    end

    it "paginates through all contact groups" do
      allow(connection).to receive(:request)
        .with(:get, "/contact_groups?contact_book=#{contact_book_id}&kind=group&limit=2")
        .and_return(first_page)
      allow(connection).to receive(:request)
        .with(:get, "/contact_groups?contact_book=#{contact_book_id}&kind=group&limit=2&offset=2")
        .and_return(page2)

      items = []
      contact_groups.each_item(contact_book: contact_book_id, kind: "group", limit: 2) { |item| items << item }

      expect(items.size).to eq(3)
      expect(items.first).to be_a(Missive::Object)
      expect(items.first.id).to eq("group_1")
      expect(items.last.id).to eq("group_3")
    end

    it "raises ArgumentError when contact_book is missing" do
      expect do
        contact_groups.each_item(kind: "group") { |_| } # rubocop:disable Lint/EmptyBlock
      end.to raise_error(ArgumentError, "contact_book is required")
    end

    it "raises ArgumentError when kind is missing" do
      expect do
        contact_groups.each_item(contact_book: contact_book_id) { |_| } # rubocop:disable Lint/EmptyBlock
      end.to raise_error(ArgumentError, "kind is required")
    end

    it "raises ArgumentError when kind is invalid" do
      expect do
        contact_groups.each_item(contact_book: contact_book_id, kind: "invalid") { |_| } # rubocop:disable Lint/EmptyBlock
      end.to raise_error(ArgumentError, "kind must be 'group' or 'organization'")
    end
  end
end
