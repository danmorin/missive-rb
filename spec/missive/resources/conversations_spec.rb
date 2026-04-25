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

  # ----------------------------------------------------------------------
  # Conversation actions — close, reopen, label, assign, inbox, merge
  # ----------------------------------------------------------------------

  let(:posts_resource) { instance_double("Missive::Resources::Posts") }
  let(:post_response) { Missive::Object.new({ "id" => "post-999" }, client) }
  let(:default_notification) { { title: kind_of(String), body: "via Missive API" } }

  describe "#close" do
    before { allow(client).to receive(:posts).and_return(posts_resource) }

    it "calls posts.create with conversation + close: true + default notification" do
      expect(posts_resource).to receive(:create) do |**args|
        expect(args[:conversation]).to eq("conv-123")
        expect(args[:close]).to eq(true)
        expect(args[:notification]).to eq(title: "Conversation closed", body: "via Missive API")
        post_response
      end

      result = resource.close(id: "conv-123")
      expect(result).to eq(post_response)
    end

    it "passes through optional attrs alongside the default notification" do
      expect(posts_resource).to receive(:create) do |**args|
        expect(args[:close]).to eq(true)
        expect(args[:text]).to eq("Resolved.")
        expect(args[:notification][:title]).to eq("Conversation closed")
        post_response
      end

      resource.close(id: "conv-123", text: "Resolved.")
    end

    it "lets callers override the default notification" do
      custom = { title: "Custom", body: "Custom body" }
      expect(posts_resource).to receive(:create) do |**args|
        expect(args[:notification]).to eq(custom)
        post_response
      end

      resource.close(id: "conv-123", notification: custom)
    end

    it "raises ArgumentError when id is missing" do
      expect { resource.close(id: nil) }.to raise_error(ArgumentError, "id is required")
      expect { resource.close(id: "") }.to raise_error(ArgumentError, "id is required")
    end
  end

  describe "#reopen" do
    before { allow(client).to receive(:posts).and_return(posts_resource) }

    it "calls posts.create with reopen: true + default notification" do
      expect(posts_resource).to receive(:create) do |**args|
        expect(args[:reopen]).to eq(true)
        expect(args[:notification]).to eq(title: "Conversation reopened", body: "via Missive API")
        post_response
      end

      resource.reopen(id: "conv-123")
    end

    it "raises ArgumentError when id is missing" do
      expect { resource.reopen(id: nil) }.to raise_error(ArgumentError, "id is required")
    end
  end

  describe "#add_labels" do
    before { allow(client).to receive(:posts).and_return(posts_resource) }

    it "calls posts.create with add_shared_labels + default notification" do
      expect(posts_resource).to receive(:create) do |**args|
        expect(args[:add_shared_labels]).to eq(["lbl-1", "lbl-2"])
        expect(args[:notification]).to eq(title: "Labels added", body: "via Missive API")
        post_response
      end

      resource.add_labels(id: "conv-123", labels: ["lbl-1", "lbl-2"])
    end

    it "raises when labels is not an array" do
      expect { resource.add_labels(id: "conv-123", labels: "lbl-1") }
        .to raise_error(ArgumentError, "labels must be an array")
    end

    it "raises when labels is empty" do
      expect { resource.add_labels(id: "conv-123", labels: []) }
        .to raise_error(ArgumentError, "labels cannot be empty")
    end

    it "raises when any label entry is blank" do
      expect { resource.add_labels(id: "conv-123", labels: ["lbl-1", ""]) }
        .to raise_error(ArgumentError, "labels entries must be non-blank strings")
    end

    it "raises when id is missing" do
      expect { resource.add_labels(id: nil, labels: ["lbl-1"]) }
        .to raise_error(ArgumentError, "id is required")
    end
  end

  describe "#remove_labels" do
    before { allow(client).to receive(:posts).and_return(posts_resource) }

    it "calls posts.create with remove_shared_labels + default notification" do
      expect(posts_resource).to receive(:create) do |**args|
        expect(args[:remove_shared_labels]).to eq(["lbl-1"])
        expect(args[:notification]).to eq(title: "Labels removed", body: "via Missive API")
        post_response
      end

      resource.remove_labels(id: "conv-123", labels: ["lbl-1"])
    end

    it "raises when labels is empty" do
      expect { resource.remove_labels(id: "conv-123", labels: []) }
        .to raise_error(ArgumentError, "labels cannot be empty")
    end
  end

  describe "#assign" do
    before { allow(client).to receive(:posts).and_return(posts_resource) }

    it "calls posts.create with add_assignees + organization + default notification" do
      expect(posts_resource).to receive(:create) do |**args|
        expect(args[:add_assignees]).to eq(["user-1"])
        expect(args[:organization]).to eq("org-1")
        expect(args[:notification]).to eq(title: "Assignees updated", body: "via Missive API")
        post_response
      end

      resource.assign(id: "conv-123", users: ["user-1"], organization: "org-1")
    end

    it "raises when users is empty" do
      expect { resource.assign(id: "conv-123", users: [], organization: "org-1") }
        .to raise_error(ArgumentError, "users cannot be empty")
    end

    it "raises when organization is missing" do
      expect { resource.assign(id: "conv-123", users: ["user-1"], organization: nil) }
        .to raise_error(ArgumentError, "organization is required")
    end
  end

  describe "#add_to_inbox" do
    before { allow(client).to receive(:posts).and_return(posts_resource) }

    it "calls posts.create with add_to_inbox: true + default notification" do
      expect(posts_resource).to receive(:create) do |**args|
        expect(args[:add_to_inbox]).to eq(true)
        expect(args[:notification]).to eq(title: "Moved to inbox", body: "via Missive API")
        post_response
      end

      resource.add_to_inbox(id: "conv-123")
    end
  end

  describe "#add_to_team_inbox" do
    before { allow(client).to receive(:posts).and_return(posts_resource) }

    it "calls posts.create with add_to_team_inbox + team + default notification" do
      expect(posts_resource).to receive(:create) do |**args|
        expect(args[:add_to_team_inbox]).to eq(true)
        expect(args[:team]).to eq("team-1")
        expect(args[:notification]).to eq(title: "Moved to team inbox", body: "via Missive API")
        post_response
      end

      resource.add_to_team_inbox(id: "conv-123", team: "team-1")
    end

    it "raises when team is missing" do
      expect { resource.add_to_team_inbox(id: "conv-123", team: nil) }
        .to raise_error(ArgumentError, "team is required")
    end
  end

  describe "#merge" do
    let(:merge_response) do
      { conversations: [{ "id" => "dst-456", "subject" => "Merged" }] }
    end

    it "POSTs to /conversations/:id/merge with target body" do
      expect(connection).to receive(:request)
        .with(:post, "/conversations/src-123/merge", body: { target: "dst-456" })
        .and_return(merge_response)

      result = resource.merge(id: "src-123", target: "dst-456")
      expect(result).to be_a(Missive::Object)
      expect(result.id).to eq("dst-456")
    end

    it "includes subject when provided" do
      expect(connection).to receive(:request)
        .with(:post, "/conversations/src-123/merge", body: { target: "dst-456", subject: "Combined" })
        .and_return(merge_response)

      resource.merge(id: "src-123", target: "dst-456", subject: "Combined")
    end

    it "raises when id and target are identical" do
      expect { resource.merge(id: "same-id", target: "same-id") }
        .to raise_error(ArgumentError, "id and target must differ")
    end

    it "raises when target is missing" do
      expect { resource.merge(id: "src-123", target: nil) }
        .to raise_error(ArgumentError, "target is required")
    end

    it "raises when response has no conversations" do
      allow(connection).to receive(:request).and_return({ conversations: [] })

      expect { resource.merge(id: "src-123", target: "dst-456") }
        .to raise_error(Missive::ServerError, "Merge failed")
    end
  end
end
