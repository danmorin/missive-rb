# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"
require_relative "../../support/shared_examples/message_endpoint_examples"

RSpec.describe Missive::Resources::Messages do
  let(:client) { instance_double("Missive::Client") }
  let(:connection) { instance_double("Missive::Connection") }
  let(:resource) { described_class.new(client) }

  before do
    allow(client).to receive(:connection).and_return(connection)
  end

  describe "#initialize" do
    it "stores the client" do
      expect(resource.client).to eq(client)
    end
  end

  describe "#create" do
    let(:message_response) do
      { id: "msg-123", body: "Test message", account: "channel-id" }
    end

    let(:message_data) do
      {
        account: "channel-id",
        from_field: { id: "123", username: "@bot" },
        to_fields: [{ id: "321", username: "@user" }],
        body: "Test message"
      }
    end

    before do
      allow(connection).to receive(:request).and_return(message_response)
    end

    it "sends POST request with correct payload" do
      resource.create(**message_data)

      expect(connection).to have_received(:request).with(
        :post,
        "/messages",
        body: message_data
      )
    end

    it "includes additional attributes in request body" do
      extra_attrs = { custom_field: "value", priority: "high" }
      expected_body = message_data.merge(extra_attrs)

      resource.create(**message_data, **extra_attrs)

      expect(connection).to have_received(:request).with(
        :post,
        "/messages",
        body: expected_body
      )
    end

    it "raises ArgumentError when account is nil" do
      expect do
        resource.create(
          account: nil,
          from_field: { id: "123" },
          to_fields: [{ id: "321" }],
          body: "Test"
        )
      end.to raise_error(ArgumentError, "account parameter is required")
    end

    it "raises ArgumentError when account is empty" do
      expect do
        resource.create(
          account: "",
          from_field: { id: "123" },
          to_fields: [{ id: "321" }],
          body: "Test"
        )
      end.to raise_error(ArgumentError, "account parameter is required")
    end

    it "emits instrumentation event" do
      notifications = []
      ActiveSupport::Notifications.subscribe("missive.messages.create") do |_name, _start, _finish, _id, payload|
        notifications << payload
      end

      resource.create(**message_data)

      expect(notifications).not_to be_empty
      expect(notifications.first).to include(body: message_data)
    end

    it "returns Missive::Object instance" do
      result = resource.create(**message_data)

      expect(result).to be_a(Missive::Object)
      expect(result.id).to eq("msg-123")
      expect(result.body).to eq("Test message")
    end

    it "handles server errors by letting them bubble up" do
      allow(connection).to receive(:request).and_raise(Missive::ServerError.new("Server error"))

      expect do
        resource.create(**message_data)
      end.to raise_error(Missive::ServerError)
    end
  end

  describe "#create_for_custom_channel" do
    let(:channel_id) { "fbf74c47-d0a0-4d77-bf3c-2118025d8102" }
    let(:message_data) do
      {
        from_field: { id: "123", username: "@bot" },
        to_fields: [{ id: "321", username: "@user" }],
        body: "Test message"
      }
    end

    let(:expected_create_params) do
      {
        account: channel_id,
        from_field: { id: "123", username: "@bot" },
        to_fields: [{ id: "321", username: "@user" }],
        body: "Test message"
      }
    end

    before do
      allow(connection).to receive(:request).and_return({ id: "msg-123" })
    end

    it "forwards to create method with account set to channel_id" do
      resource.create_for_custom_channel(channel_id: channel_id, **message_data)

      expect(connection).to have_received(:request).with(
        :post,
        "/messages",
        body: expected_create_params
      )
    end

    it "returns Missive::Object instance" do
      result = resource.create_for_custom_channel(channel_id: channel_id, **message_data)

      expect(result).to be_a(Missive::Object)
      expect(result.id).to eq("msg-123")
    end
  end

  describe "#get" do
    let(:message_response) do
      { messages: { id: "msg-123", body: "Test message", attachments: [] } }
    end

    before do
      allow(connection).to receive(:request).and_return(message_response)
    end

    subject { resource.get(id: "msg-123") }

    it "sends GET request to correct path" do
      resource.get(id: "msg-123")

      expect(connection).to have_received(:request).with(:get, "/messages/msg-123")
    end

    it "emits instrumentation event" do
      notifications = []
      ActiveSupport::Notifications.subscribe("missive.messages.get") do |_name, _start, _finish, _id, payload|
        notifications << payload
      end

      resource.get(id: "msg-123")

      expect(notifications).not_to be_empty
      expect(notifications.first).to include(id: "msg-123")
    end

    it "returns Missive::Object instance" do
      result = resource.get(id: "msg-123")

      expect(result).to be_a(Missive::Object)
      expect(result.id).to eq("msg-123")
      expect(result.body).to eq("Test message")
    end

    it "handles 404 errors" do
      allow(connection).to receive(:request).and_raise(Missive::NotFoundError.new("Not found"))

      expect do
        resource.get(id: "non-existent")
      end.to raise_error(Missive::NotFoundError)
    end

    it "raises NotFoundError when messages key is missing" do
      allow(connection).to receive(:request).and_return({})

      expect do
        resource.get(id: "msg-123")
      end.to raise_error(Missive::NotFoundError, "Message not found")
    end

    it "raises NotFoundError when messages is nil" do
      allow(connection).to receive(:request).and_return({ messages: nil })

      expect do
        resource.get(id: "msg-123")
      end.to raise_error(Missive::NotFoundError, "Message not found")
    end
  end

  describe "#list_by_email_message_id" do
    let(:messages_response) do
      {
        messages: [
          { id: "msg-1", email_message_id: "email-123" },
          { id: "msg-2", email_message_id: "email-123" }
        ]
      }
    end

    before do
      allow(connection).to receive(:request).and_return(messages_response)
    end

    subject { resource.list_by_email_message_id(email_message_id: "email-123") }

    it "sends GET request with correct query parameter" do
      resource.list_by_email_message_id(email_message_id: "email-123")

      expect(connection).to have_received(:request).with(
        :get,
        "/messages",
        params: { email_message_id: "email-123" }
      )
    end

    it "raises ArgumentError when email_message_id is nil" do
      expect do
        resource.list_by_email_message_id(email_message_id: nil)
      end.to raise_error(ArgumentError, "email_message_id is required")
    end

    it "raises ArgumentError when email_message_id is empty" do
      expect do
        resource.list_by_email_message_id(email_message_id: "")
      end.to raise_error(ArgumentError, "email_message_id is required")
    end

    it "emits instrumentation event" do
      notifications = []
      ActiveSupport::Notifications.subscribe("missive.messages.list") do |_name, _start, _finish, _id, payload|
        notifications << payload
      end

      resource.list_by_email_message_id(email_message_id: "email-123")

      expect(notifications).not_to be_empty
      expect(notifications.first).to include(params: { email_message_id: "email-123" })
    end

    it "returns array of Missive::Object instances" do
      result = resource.list_by_email_message_id(email_message_id: "email-123")

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(Missive::Object))
      expect(result.first.id).to eq("msg-1")
    end

    it_behaves_like "message endpoint"
  end
end
