# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/shared_examples/list_endpoint_examples"

RSpec.describe Missive::Resources::Contacts do
  let(:client) { instance_double("Missive::Client") }
  let(:connection) { instance_double("Missive::Connection") }
  let(:contacts) { described_class.new(client) }
  subject { contacts }

  before do
    allow(client).to receive(:connection).and_return(connection)
  end

  describe "#initialize" do
    it "stores the client" do
      expect(contacts.client).to eq(client)
    end
  end

  describe "#create" do
    let(:contact_data) do
      {
        "email" => "john@example.com",
        "first_name" => "John",
        "last_name" => "Doe",
        "contact_book" => "book_123"
      }
    end

    let(:response) do
      {
        contacts: [
          {
            id: "contact_123",
            email: "john@example.com",
            first_name: "John",
            last_name: "Doe"
          }
        ]
      }
    end

    it "sends POST request with correct payload for single contact" do
      allow(connection).to receive(:request).and_return(response)

      result = contacts.create(contacts: contact_data)

      expect(connection).to have_received(:request).with(
        :post,
        "/contacts",
        body: { contacts: [contact_data] }
      )
      expect(result).to be_an(Array)
      expect(result.length).to eq(1)
      expect(result.first).to be_a(Missive::Object)
      expect(result.first.id).to eq("contact_123")
      expect(result.first.email).to eq("john@example.com")
      expect(result.first.client).to eq(client)
    end

    it "sends POST request with correct payload for array of contacts" do
      contact_array = [contact_data, contact_data.merge("email" => "jane@example.com")]
      allow(connection).to receive(:request).and_return(response)

      contacts.create(contacts: contact_array)

      expect(connection).to have_received(:request).with(
        :post,
        "/contacts",
        body: { contacts: contact_array }
      )
    end

    it "emits missive.contacts.create notification" do
      allow(connection).to receive(:request).and_return(response)
      notifications = []

      ActiveSupport::Notifications.subscribe("missive.contacts.create") do |_name, _start, _finish, _id, payload|
        notifications << payload
      end

      contacts.create(contacts: contact_data)

      expect(notifications).not_to be_empty
      expect(notifications.first[:body]).to eq({ contacts: [contact_data] })
    end

    it "handles server errors by letting them bubble up" do
      allow(connection).to receive(:request).and_raise(Missive::ServerError)

      expect do
        contacts.create(contacts: contact_data)
      end.to raise_error(Missive::ServerError)
    end

    it "handles missing contact_book validation error" do
      allow(connection).to receive(:request).and_raise(
        Missive::ServerError.new("Validation failed: contact_book is required")
      )

      expect do
        contacts.create(contacts: { "email" => "test@example.com" })
      end.to raise_error(Missive::ServerError, "Validation failed: contact_book is required")
    end

    it "handles empty contacts array in response" do
      empty_response = { contacts: [] }
      allow(connection).to receive(:request).and_return(empty_response)

      result = contacts.create(contacts: contact_data)

      expect(result).to be_an(Array)
      expect(result).to be_empty
    end

    it "handles missing contacts key in response" do
      bad_response = {}
      allow(connection).to receive(:request).and_return(bad_response)

      result = contacts.create(contacts: contact_data)

      expect(result).to be_an(Array)
      expect(result).to be_empty
    end
  end

  describe "#update" do
    let(:contact_update) do
      {
        "id" => "contact_123",
        "first_name" => "Jane",
        "last_name" => "Smith"
      }
    end

    let(:response) do
      {
        contacts: [
          {
            id: "contact_123",
            email: "jane@example.com",
            first_name: "Jane",
            last_name: "Smith"
          }
        ]
      }
    end

    it "sends PATCH request with correct URI and payload" do
      allow(connection).to receive(:request).and_return(response)

      result = contacts.update(contact_hashes: contact_update)

      expect(connection).to have_received(:request).with(
        :patch,
        "/contacts/contact_123",
        body: { contacts: [contact_update] }
      )
      expect(result).to be_an(Array)
      expect(result.first).to be_a(Missive::Object)
      expect(result.first.id).to eq("contact_123")
      expect(result.first.client).to eq(client)
    end

    it "builds correct URI with multiple ids" do
      updates = [
        { "id" => "contact_123", "first_name" => "Jane" },
        { "id" => "contact_456", "first_name" => "John" }
      ]
      allow(connection).to receive(:request).and_return(response)

      contacts.update(contact_hashes: updates)

      expect(connection).to have_received(:request).with(
        :patch,
        "/contacts/contact_123,contact_456",
        body: { contacts: updates }
      )
    end

    it "raises ArgumentError when id is missing" do
      expect do
        contacts.update(contact_hashes: { "first_name" => "Jane" })
      end.to raise_error(ArgumentError, "Each contact must have an 'id' field")
    end

    it "emits missive.contacts.update notification" do
      allow(connection).to receive(:request).and_return(response)
      notifications = []

      ActiveSupport::Notifications.subscribe("missive.contacts.update") do |_name, _start, _finish, _id, payload|
        notifications << payload
      end

      contacts.update(contact_hashes: contact_update)

      expect(notifications).not_to be_empty
      expect(notifications.first[:path]).to eq("/contacts/contact_123")
      expect(notifications.first[:body]).to eq({ contacts: [contact_update] })
    end

    it "handles empty contacts array in response" do
      empty_response = { contacts: [] }
      allow(connection).to receive(:request).and_return(empty_response)

      result = contacts.update(contact_hashes: contact_update)

      expect(result).to be_an(Array)
      expect(result).to be_empty
    end

    it "handles missing contacts key in response" do
      bad_response = {}
      allow(connection).to receive(:request).and_return(bad_response)

      result = contacts.update(contact_hashes: contact_update)

      expect(result).to be_an(Array)
      expect(result).to be_empty
    end

    it "strips keys outside allowed schema by default" do
      update_with_extra = {
        "id" => "contact_123",
        "first_name" => "Jane",
        "invalid_field" => "should be stripped",
        "another_bad_field" => "also stripped"
      }
      allow(connection).to receive(:request).and_return(response)

      contacts.update(contact_hashes: update_with_extra)

      expect(connection).to have_received(:request).with(
        :patch,
        "/contacts/contact_123",
        body: { contacts: [{ "id" => "contact_123", "first_name" => "Jane" }] }
      )
    end

    it "preserves all keys when skip_validation is true" do
      update_with_extra = {
        "id" => "contact_123",
        "first_name" => "Jane",
        "custom_field_xyz" => "should be kept"
      }
      allow(connection).to receive(:request).and_return(response)

      contacts.update(contact_hashes: update_with_extra, skip_validation: true)

      expect(connection).to have_received(:request).with(
        :patch,
        "/contacts/contact_123",
        body: { contacts: [update_with_extra] }
      )
    end

    it "handles both string and symbol ids" do
      updates = [
        { "id" => "contact_123", "first_name" => "Jane" },
        { id: "contact_456", first_name: "John" }
      ]
      allow(connection).to receive(:request).and_return(response)

      contacts.update(contact_hashes: updates)

      expect(connection).to have_received(:request).with(
        :patch,
        "/contacts/contact_123,contact_456",
        body: { contacts: [
          { "id" => "contact_123", "first_name" => "Jane" },
          { id: "contact_456", first_name: "John" }
        ] }
      )
    end

    it "accepts a hash instead of array" do
      allow(connection).to receive(:request).and_return(response)

      result = contacts.update(contact_hashes: contact_update)

      expect(result).to be_an(Array)
      expect(result.length).to eq(1)
    end

    it "validates skip_validation parameter is boolean" do
      allow(connection).to receive(:request).and_return(response)

      # Test with explicit false
      contacts.update(contact_hashes: contact_update, skip_validation: false)

      expect(connection).to have_received(:request).with(
        :patch,
        "/contacts/contact_123",
        body: { contacts: [contact_update] }
      )
    end
  end

  describe "#list" do
    let(:response) do
      {
        contacts: [
          { id: "1", email: "test1@example.com" },
          { id: "2", email: "test2@example.com" }
        ],
        offset: 0,
        limit: 50
      }
    end
    let(:list_path) { "/contacts" }

    it_behaves_like "a list endpoint", :contacts

    it "validates modified_since is numeric" do
      expect do
        contacts.list(modified_since: "2023-01-01")
      end.to raise_error(ArgumentError, "modified_since must be a numeric epoch timestamp")
    end

    it "accepts numeric modified_since" do
      allow(connection).to receive(:request).and_return(response)

      contacts.list(modified_since: 1_672_531_200)

      expect(connection).to have_received(:request).with(
        :get,
        "/contacts",
        params: { limit: 50, offset: 0, modified_since: 1_672_531_200 }
      )
    end
  end

  describe "#each_item" do
    let(:first_page) do
      {
        contacts: [
          { id: "1", email: "test1@example.com" },
          { id: "2", email: "test2@example.com" }
        ],
        offset: 0,
        limit: 2
      }
    end
    let(:data_key) { :contacts }
    let(:required_params) { {} }

    it_behaves_like "a paginated list endpoint"

    let(:page2) do
      {
        contacts: [
          { id: "3", email: "test3@example.com" }
        ],
        offset: 2,
        limit: 2
      }
    end

    it "paginates through all contacts" do
      allow(connection).to receive(:request).with(:get, "/contacts?limit=2").and_return(first_page)
      allow(connection).to receive(:request).with(:get, "/contacts?limit=2&offset=2").and_return(page2)

      items = []
      contacts.each_item(limit: 2) { |item| items << item }

      expect(items.size).to eq(3)
      expect(items.first).to be_a(Missive::Object)
      expect(items.first.id).to eq("1")
      expect(items.last.id).to eq("3")
    end
  end

  describe "#get" do
    let(:contact_id) { "contact_123" }
    let(:response) do
      {
        contacts: [
          {
            id: contact_id,
            email: "john@example.com",
            first_name: "John",
            last_name: "Doe"
          }
        ]
      }
    end

    it "sends GET request to correct path" do
      allow(connection).to receive(:request).and_return(response)

      result = contacts.get(id: contact_id)

      expect(connection).to have_received(:request).with(:get, "/contacts/contact_123")
      expect(result).to be_a(Missive::Object)
      expect(result.id).to eq(contact_id)
    end

    it "emits missive.contacts.get notification" do
      allow(connection).to receive(:request).and_return(response)
      notifications = []

      ActiveSupport::Notifications.subscribe("missive.contacts.get") do |_name, _start, _finish, _id, payload|
        notifications << payload
      end

      contacts.get(id: contact_id)

      expect(notifications).not_to be_empty
      expect(notifications.first[:id]).to eq(contact_id)
    end

    it "handles 404 errors" do
      allow(connection).to receive(:request).and_raise(Missive::NotFoundError)

      expect do
        contacts.get(id: "nonexistent")
      end.to raise_error(Missive::NotFoundError)
    end

    it "raises NotFoundError when contacts array is empty" do
      allow(connection).to receive(:request).and_return({ contacts: [] })

      expect do
        contacts.get(id: "nonexistent")
      end.to raise_error(Missive::NotFoundError, "Contact not found")
    end
  end
end
