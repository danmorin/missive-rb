# frozen_string_literal: true

require "spec_helper"

RSpec.describe Missive::Resources::ContactBooks do
  let(:client) { instance_double("Missive::Client") }
  let(:connection) { instance_double("Missive::Connection") }
  let(:contact_books) { described_class.new(client) }
  subject { contact_books }

  before do
    allow(client).to receive(:connection).and_return(connection)
  end

  describe "#initialize" do
    it "stores the client" do
      expect(contact_books.client).to eq(client)
    end
  end

  describe "#list" do
    let(:response) do
      {
        contact_books: [
          { id: "book_1", name: "Personal Contacts" },
          { id: "book_2", name: "Work Contacts" }
        ],
        offset: 0,
        limit: 50
      }
    end

    it "sends GET request with default parameters" do
      expect(connection).to receive(:request).with(
        :get,
        "/contact_books",
        params: { limit: 50, offset: 0 }
      ).and_return(response)

      contact_books.list
    end

    it "raises ArgumentError when limit exceeds 200" do
      expect do
        contact_books.list(limit: 201)
      end.to raise_error(ArgumentError, "limit cannot exceed 200")
    end
  end

  describe "#each_item" do
    let(:first_page) do
      {
        contact_books: [
          { id: "book_1", name: "Personal" },
          { id: "book_2", name: "Work" }
        ],
        offset: 0,
        limit: 2
      }
    end

    it "raises ArgumentError when limit exceeds 200" do
      expect do
        contact_books.each_item(limit: 201) { |_| } # rubocop:disable Lint/EmptyBlock
      end.to raise_error(ArgumentError, "limit cannot exceed 200")
    end

    it "calls Paginator.each_item with correct parameters" do
      expect(Missive::Paginator).to receive(:each_item).with(
        path: "/contact_books",
        client: client,
        params: { limit: 50 },
        data_key: :contact_books
      )

      contact_books.each_item { |_| } # rubocop:disable Lint/EmptyBlock
    end

    it "paginates through all contact books" do
      page2 = {
        contact_books: [
          { id: "book_3", name: "Vendors" }
        ],
        offset: 2,
        limit: 2
      }

      allow(connection).to receive(:request).with(:get, "/contact_books?limit=2").and_return(first_page)
      allow(connection).to receive(:request).with(:get, "/contact_books?limit=2&offset=2").and_return(page2)

      items = []
      contact_books.each_item(limit: 2) { |item| items << item }

      expect(items.size).to eq(3)
      expect(items.first).to be_a(Missive::Object)
      expect(items.first.id).to eq("book_1")
      expect(items.last.id).to eq("book_3")
    end
  end
end
