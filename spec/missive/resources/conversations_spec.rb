# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"
require_relative "../../support/shared_examples/message_endpoint_examples"

RSpec.describe Missive::Resources::Conversations do
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

  describe "#list" do
    let(:conversations_response) do
      {
        conversations: [
          { id: "conv-1", subject: "Test Subject 1" },
          { id: "conv-2", subject: "Test Subject 2" }
        ]
      }
    end

    before do
      allow(connection).to receive(:request).and_return(conversations_response)
    end

    it "sends GET request with default parameters" do
      resource.list

      expect(connection).to have_received(:request).with(
        :get,
        "/conversations",
        params: { limit: 25 }
      )
    end

    it "sends GET request with custom parameters" do
      resource.list(limit: 10, inbox: true)

      expect(connection).to have_received(:request).with(
        :get,
        "/conversations",
        params: { limit: 10, inbox: true }
      )
    end

    it "sends GET request with until parameter" do
      resource.list(limit: 10, until_cursor: "2024-01-01T10:00:00Z")

      expect(connection).to have_received(:request).with(
        :get,
        "/conversations",
        params: { limit: 10, until: "2024-01-01T10:00:00Z" }
      )
    end

    it "raises ArgumentError when limit exceeds 50" do
      expect do
        resource.list(limit: 51)
      end.to raise_error(ArgumentError, "limit cannot exceed 50")
    end

    it "emits instrumentation event" do
      notifications = []
      ActiveSupport::Notifications.subscribe("missive.conversations.list") do |_name, _start, _finish, _id, payload|
        notifications << payload
      end

      resource.list(inbox: true)

      expect(notifications).not_to be_empty
      expect(notifications.first).to include(params: { limit: 25, inbox: true })
    end

    it "returns array of Missive::Object instances" do
      result = resource.list

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(Missive::Object))
      expect(result.first.id).to eq("conv-1")
    end

    it "handles empty conversations array in response" do
      allow(connection).to receive(:request).and_return({ conversations: [] })

      result = resource.list

      expect(result).to eq([])
    end

    it "handles missing conversations key in response" do
      allow(connection).to receive(:request).and_return({})

      result = resource.list

      expect(result).to eq([])
    end
  end

  describe "#each_item" do
    let(:page1) do
      {
        conversations: Array.new(25) do |i|
          { id: "conv-#{i + 1}", subject: "Test Subject #{i + 1}", created_at: 1_563_806_400 - (i * 10) }
        end
      }
    end

    let(:page2) do
      {
        conversations: [
          { id: "conv-26", subject: "Test Subject 26", created_at: 1_563_806_150 }
        ]
      }
    end

    before do
      allow(connection).to receive(:request).with(:get, "/conversations?inbox=true&limit=25").and_return(page1)
      allow(connection).to receive(:request).with(:get, "/conversations?inbox=true&limit=25&until=1563806160").and_return(page2)
    end

    it "paginates through all conversations" do
      conversations = []
      resource.each_item(inbox: true) do |conversation|
        conversations << conversation
      end

      expect(conversations.size).to eq(26)
      expect(conversations).to all(be_a(Missive::Object))
      expect(conversations.first.id).to eq("conv-1")
      expect(conversations.last.id).to eq("conv-26")
    end

    it "raises ArgumentError when limit exceeds 50" do
      expect do
        resource.each_item(limit: 51) { |_| nil }
      end.to raise_error(ArgumentError, "limit cannot exceed 50")
    end

    it "uses default limit when not provided" do
      allow(connection).to receive(:request).with(:get, "/conversations?limit=25").and_return({ conversations: [] })

      resource.each_item { |_| nil }

      expect(connection).to have_received(:request).with(:get, "/conversations?limit=25")
    end
  end

  describe "#get" do
    let(:conversation_response) do
      {
        "conversations" => [
          { id: "conv-123", subject: "Test Subject" }
        ]
      }
    end

    before do
      allow(connection).to receive(:request).and_return(conversation_response)
    end

    it "sends GET request to correct path" do
      resource.get(id: "conv-123")

      expect(connection).to have_received(:request).with(:get, "/conversations/conv-123")
    end

    it "emits instrumentation event" do
      notifications = []
      ActiveSupport::Notifications.subscribe("missive.conversations.get") do |_name, _start, _finish, _id, payload|
        notifications << payload
      end

      resource.get(id: "conv-123")

      expect(notifications).not_to be_empty
      expect(notifications.first).to include(id: "conv-123")
    end

    it "returns Missive::Object instance" do
      result = resource.get(id: "conv-123")

      expect(result).to be_a(Missive::Object)
      expect(result.id).to eq("conv-123")
      expect(result.subject).to eq("Test Subject")
    end

    it "handles 404 errors" do
      allow(connection).to receive(:request).and_raise(Missive::NotFoundError.new("Not found"))

      expect do
        resource.get(id: "non-existent")
      end.to raise_error(Missive::NotFoundError)
    end
  end

  describe "#messages" do
    let(:messages_response) do
      {
        messages: [
          { id: "msg-1", body: "Test message 1" },
          { id: "msg-2", body: "Test message 2" }
        ]
      }
    end

    before do
      allow(connection).to receive(:request).and_return(messages_response)
    end

    subject { resource.messages(conversation_id: "conv-123") }

    it "sends GET request to correct path" do
      resource.messages(conversation_id: "conv-123")

      expect(connection).to have_received(:request).with(
        :get,
        "/conversations/conv-123/messages",
        params: { limit: 10 }
      )
    end

    it "sends GET request with custom limit" do
      resource.messages(conversation_id: "conv-123", limit: 5)

      expect(connection).to have_received(:request).with(
        :get,
        "/conversations/conv-123/messages",
        params: { limit: 5 }
      )
    end

    it "sends GET request with until parameter" do
      resource.messages(conversation_id: "conv-123", until_cursor: "token123")

      expect(connection).to have_received(:request).with(
        :get,
        "/conversations/conv-123/messages",
        params: { limit: 10, until: "token123" }
      )
    end

    it "raises ArgumentError when limit exceeds 10" do
      expect do
        resource.messages(conversation_id: "conv-123", limit: 11)
      end.to raise_error(ArgumentError, "limit cannot exceed 10")
    end

    it "emits instrumentation event" do
      notifications = []
      ActiveSupport::Notifications.subscribe("missive.conversations.messages") do |_name, _start, _finish, _id, payload|
        notifications << payload
      end

      resource.messages(conversation_id: "conv-123")

      expect(notifications).not_to be_empty
      expect(notifications.first).to include(conversation_id: "conv-123")
    end

    it_behaves_like "message endpoint"
  end

  describe "#each_message" do
    let(:page1) do
      {
        messages: Array.new(10) do |i|
          { id: "msg-#{i + 1}", body: "Test message #{i + 1}", delivered_at: 1_563_806_400 - (i * 10) }
        end
      }
    end

    let(:page2) do
      {
        messages: [
          { id: "msg-11", body: "Test message 11", delivered_at: 1_563_806_300 }
        ]
      }
    end

    before do
      allow(connection).to receive(:request).with(:get, "/conversations/conv-123/messages?limit=10").and_return(page1)
      allow(connection).to receive(:request).with(:get,
                                                  "/conversations/conv-123/messages?limit=10&until=1563806310").and_return(page2)
    end

    it "paginates through all messages" do
      messages = []
      resource.each_message(conversation_id: "conv-123") do |message|
        messages << message
      end

      expect(messages.size).to eq(11)
      expect(messages).to all(be_a(Missive::Object))
      expect(messages.first.id).to eq("msg-1")
      expect(messages.last.id).to eq("msg-11")
    end

    it "raises ArgumentError when limit exceeds 10" do
      expect do
        resource.each_message(conversation_id: "conv-123", limit: 11) { |_| nil }
      end.to raise_error(ArgumentError, "limit cannot exceed 10")
    end
  end

  describe "#comments" do
    let(:comments_response) do
      {
        comments: [
          { id: "comment-1", body: "Test comment 1" },
          { id: "comment-2", body: "Test comment 2" }
        ]
      }
    end

    before do
      allow(connection).to receive(:request).and_return(comments_response)
    end

    it "sends GET request to correct path" do
      resource.comments(conversation_id: "conv-123")

      expect(connection).to have_received(:request).with(
        :get,
        "/conversations/conv-123/comments",
        params: { limit: 10 }
      )
    end

    it "sends GET request with custom limit" do
      resource.comments(conversation_id: "conv-123", limit: 5)

      expect(connection).to have_received(:request).with(
        :get,
        "/conversations/conv-123/comments",
        params: { limit: 5 }
      )
    end

    it "sends GET request with until parameter" do
      resource.comments(conversation_id: "conv-123", until_cursor: "token123")

      expect(connection).to have_received(:request).with(
        :get,
        "/conversations/conv-123/comments",
        params: { limit: 10, until: "token123" }
      )
    end

    it "raises ArgumentError when limit exceeds 10" do
      expect do
        resource.comments(conversation_id: "conv-123", limit: 11)
      end.to raise_error(ArgumentError, "limit cannot exceed 10")
    end

    it "emits instrumentation event" do
      notifications = []
      ActiveSupport::Notifications.subscribe("missive.conversations.comments") do |_name, _start, _finish, _id, payload|
        notifications << payload
      end

      resource.comments(conversation_id: "conv-123")

      expect(notifications).not_to be_empty
      expect(notifications.first).to include(conversation_id: "conv-123")
    end

    it "returns array of Missive::Object instances" do
      result = resource.comments(conversation_id: "conv-123")

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(Missive::Object))
      expect(result.first.id).to eq("comment-1")
    end

    it "handles empty comments array in response" do
      allow(connection).to receive(:request).and_return({ comments: [] })

      result = resource.comments(conversation_id: "conv-123")

      expect(result).to eq([])
    end

    it "handles missing comments key in response" do
      allow(connection).to receive(:request).and_return({})

      result = resource.comments(conversation_id: "conv-123")

      expect(result).to eq([])
    end
  end

  describe "#each_comment" do
    let(:page1) do
      {
        comments: Array.new(10) do |i|
          { id: "comment-#{i + 1}", body: "Test comment #{i + 1}", delivered_at: 1_563_806_400 - (i * 10) }
        end
      }
    end

    let(:page2) do
      {
        comments: [
          { id: "comment-11", body: "Test comment 11", delivered_at: 1_563_806_300 }
        ]
      }
    end

    before do
      allow(connection).to receive(:request).with(:get, "/conversations/conv-123/comments?limit=10").and_return(page1)
      allow(connection).to receive(:request).with(:get,
                                                  "/conversations/conv-123/comments?limit=10&until=1563806310").and_return(page2)
    end

    it "paginates through all comments" do
      comments = []
      resource.each_comment(conversation_id: "conv-123") do |comment|
        comments << comment
      end

      expect(comments.size).to eq(11)
      expect(comments).to all(be_a(Missive::Object))
      expect(comments.first.id).to eq("comment-1")
      expect(comments.last.id).to eq("comment-11")
    end

    it "raises ArgumentError when limit exceeds 10" do
      expect do
        resource.each_comment(conversation_id: "conv-123", limit: 11) { |_| nil }
      end.to raise_error(ArgumentError, "limit cannot exceed 10")
    end
  end
end
