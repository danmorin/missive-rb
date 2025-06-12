# frozen_string_literal: true

require "spec_helper"

RSpec.describe Missive::Resources::Posts do
  let(:client) { Missive::Client.new(api_token: "test-token") }
  let(:posts) { described_class.new(client) }
  let(:connection) { instance_double(Missive::Connection) }

  before do
    allow(client).to receive(:connection).and_return(connection)
  end

  describe "#initialize" do
    it "stores the client" do
      expect(posts.instance_variable_get(:@client)).to eq(client)
    end
  end

  describe "#create" do
    let(:response_data) do
      {
        "id" => "12345",
        "markdown" => "**Test post**",
        "created_at" => "2023-01-01T00:00:00Z"
      }
    end

    context "with markdown content" do
      it "returns Missive::Object" do
        allow(connection).to receive(:request).and_return(response_data)

        result = posts.create(markdown: "**Test post**")

        expect(result).to be_a(Missive::Object)
        expect(result.id).to eq("12345")
      end

      it "POSTs correct JSON" do
        expected_payload = {
          posts: {
            markdown: "**Test post**"
          }
        }

        expect(connection).to receive(:request).with(
          :post,
          "/posts",
          body: expected_payload
        ).and_return(response_data)

        posts.create(markdown: "**Test post**")
      end
    end

    context "with text content" do
      it "creates post with plain text" do
        expected_payload = {
          posts: {
            text: "Plain text post"
          }
        }

        expect(connection).to receive(:request).with(
          :post,
          "/posts",
          body: expected_payload
        ).and_return(response_data)

        posts.create(text: "Plain text post")
      end
    end

    context "with attachments" do
      it "creates post with attachments only" do
        attachments = [{ image_url: "https://example.com/image.png" }]
        expected_payload = {
          posts: {
            attachments: attachments
          }
        }

        expect(connection).to receive(:request).with(
          :post,
          "/posts",
          body: expected_payload
        ).and_return(response_data)

        posts.create(attachments: attachments)
      end
    end

    context "with notification" do
      it "includes valid notification in payload" do
        notification = { title: "Alert", body: "Something happened" }
        expected_payload = {
          posts: {
            markdown: "Test",
            notification: notification
          }
        }

        expect(connection).to receive(:request).with(
          :post,
          "/posts",
          body: expected_payload
        ).and_return(response_data)

        posts.create(markdown: "Test", notification: notification)
      end

      it "raises error for invalid notification" do
        expect do
          posts.create(markdown: "Test", notification: { title: "Missing body" })
        end.to raise_error(ArgumentError, "Notification must include title and body")
      end
    end

    context "validation errors" do
      it "raises error when none of the content keys are provided" do
        expect do
          posts.create
        end.to raise_error(ArgumentError, "At least one of text, markdown, or attachments is required")
      end

      it "accepts any combination of content keys" do
        allow(connection).to receive(:request).and_return(response_data)

        expect { posts.create(text: "text", markdown: "**markdown**") }.not_to raise_error
        expect { posts.create(text: "text", attachments: []) }.not_to raise_error
        expect { posts.create(markdown: "**markdown**", attachments: []) }.not_to raise_error
        expect { posts.create(text: "text", markdown: "**markdown**", attachments: []) }.not_to raise_error
      end
    end

    context "instrumentation" do
      it "calls the create method within instrumentation block" do
        allow(connection).to receive(:request).and_return(response_data)

        expect(connection).to receive(:request).with(:post, "/posts", body: { posts: { markdown: "Test" } })

        posts.create(markdown: "Test")
      end
    end
  end

  describe "#delete" do
    let(:post_id) { "post-123" }

    context "successful deletion" do
      it "returns true on 204 response" do
        allow(connection).to receive(:request).with(:delete, "/posts/post-123").and_return(nil)

        result = posts.delete(id: post_id)
        expect(result).to eq(true)
      end

      it "returns true on 200 response" do
        allow(connection).to receive(:request).with(:delete, "/posts/post-123").and_return({})

        result = posts.delete(id: post_id)
        expect(result).to eq(true)
      end

      it "issues correct HTTP verb" do
        expect(connection).to receive(:request).with(
          :delete,
          "/posts/post-123"
        ).and_return(nil)

        posts.delete(id: post_id)
      end
    end

    context "error handling" do
      it "surfaces NotFoundError for 404" do
        allow(connection).to receive(:request).and_raise(
          Missive::NotFoundError.new("Post not found")
        )

        expect do
          posts.delete(id: post_id)
        end.to raise_error(Missive::NotFoundError)
      end
    end

    context "instrumentation" do
      it "calls the delete method within instrumentation block" do
        allow(connection).to receive(:request).and_return(nil)

        expect(connection).to receive(:request).with(:delete, "/posts/post-123")

        posts.delete(id: post_id)
      end
    end
  end
end
