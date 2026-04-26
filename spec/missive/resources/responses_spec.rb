# frozen_string_literal: true

require "spec_helper"

RSpec.describe Missive::Resources::Responses do
  let(:client) { Missive::Client.new(api_token: "test-token") }
  let(:responses) { described_class.new(client) }
  let(:connection) { instance_double(Missive::Connection) }
  subject { responses }

  before do
    allow(client).to receive(:connection).and_return(connection)
  end

  describe "#initialize" do
    it "stores the client" do
      expect(responses.instance_variable_get(:@client)).to eq(client)
    end
  end

  describe "#list" do
    let(:response_data) do
      {
        "responses" => [
          { "id" => "resp-1", "name" => "Auto Response 1" },
          { "id" => "resp-2", "name" => "Auto Response 2" }
        ],
        "offset" => 0,
        "limit" => 50
      }
    end

    it "sends GET request with default parameters" do
      expect(connection).to receive(:request).with(
        :get,
        "/responses",
        params: { limit: 50, offset: 0 }
      ).and_return(response_data)

      responses.list
    end

    it_behaves_like "a list endpoint", "responses", "/responses"

    context "with organization filter" do
      it_behaves_like "a list endpoint", "responses", "/responses", { organization: "org-123" }
    end

    context "with organization filter" do
      it "includes organization in params" do
        expect(connection).to receive(:request).with(
          :get,
          "/responses",
          params: { limit: 50, offset: 0, organization: "org-123" }
        ).and_return(response_data)

        responses.list(organization: "org-123")
      end
    end
  end

  describe "#each_item" do
    it_behaves_like "a paginated list endpoint", "/responses", :responses

    context "with organization filter" do
      it_behaves_like "a paginated list endpoint", "/responses", :responses, { organization: "org-123" }
    end

    it "yields Missive::Object instances from each_item" do
      # Mock the Paginator to actually call the block
      allow(Missive::Paginator).to receive(:each_item).with(
        path: "/responses",
        client: client,
        params: { limit: 50 },
        data_key: :responses
      ) do |&block|
        # This will exercise the yield line in responses.rb:48
        block.call({ "id" => "resp-1", "name" => "Test Response" })
      end

      yielded_items = []
      responses.each_item { |item| yielded_items << item }

      expect(yielded_items.length).to eq(1)
      expect(yielded_items.first).to be_a(Missive::Object)
      expect(yielded_items.first.id).to eq("resp-1")
    end

    context "organization filtering" do
      it "passes organization parameter to paginator" do
        expect(Missive::Paginator).to receive(:each_item).with(
          path: "/responses",
          client: client,
          params: hash_including(organization: "org-123"),
          data_key: :responses
        )

        responses.each_item(organization: "org-123") { |_| } # rubocop:disable Lint/EmptyBlock
      end
    end
  end

  describe "#get" do
    let(:response_id) { "resp-123" }
    let(:response_data) do
      {
        "responses" => [
          {
            "id" => "resp-123",
            "name" => "Auto Response",
            "body" => "Thank you for your message",
            "attachments" => [
              { "inline_image" => "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgA..." }
            ]
          }
        ]
      }
    end

    context "successful retrieval" do
      it "returns body with attachment inline-image handling present" do
        expect(connection).to receive(:request).with(
          :get,
          "/responses/resp-123"
        ).and_return(response_data)

        result = responses.get(id: response_id)

        expect(result).to be_a(Missive::Object)
        expect(result.id).to eq("resp-123")
        expect(result.name).to eq("Auto Response")
        expect(result.attachments.first["inline_image"]).to start_with("data:image/png")
      end

      it "sends GET request to correct path" do
        expect(connection).to receive(:request).with(
          :get,
          "/responses/resp-123"
        ).and_return(response_data)

        responses.get(id: response_id)
      end
    end

    context "error handling" do
      it "maps 404 to NotFoundError" do
        allow(connection).to receive(:request).and_raise(
          Missive::NotFoundError.new("Response not found")
        )

        expect do
          responses.get(id: response_id)
        end.to raise_error(Missive::NotFoundError)
      end
    end

    context "instrumentation" do
      it "calls the get method within instrumentation block" do
        # Test that the instrumentation block executes by ensuring the method call happens
        allow(connection).to receive(:request).and_return(response_data)

        expect(connection).to receive(:request).with(:get, "/responses/resp-123")

        responses.get(id: response_id)
      end
    end
  end

  describe "#create" do
    let(:created) { { "id" => "resp-new", "name" => "Hello", "body" => "<p>Hi</p>" } }
    let(:response_envelope) { { responses: created } }

    it "POSTs to /responses with name + body" do
      expected = { responses: { name: "Hello", body: "<p>Hi</p>" } }
      expect(connection).to receive(:request).with(:post, "/responses", body: expected).and_return(response_envelope)

      result = responses.create(name: "Hello", body: "<p>Hi</p>")
      expect(result).to be_a(Missive::Object)
      expect(result.id).to eq("resp-new")
    end

    it "merges optional attrs (organization, shared, shared_label) into payload" do
      expected = { responses: { name: "Hello", body: "<p>Hi</p>", organization: "org-1", shared: true } }
      expect(connection).to receive(:request).with(:post, "/responses", body: expected).and_return(response_envelope)

      responses.create(name: "Hello", body: "<p>Hi</p>", organization: "org-1", shared: true)
    end

    it "raises ArgumentError when name is blank" do
      expect { responses.create(name: "", body: "<p>Hi</p>") }
        .to raise_error(ArgumentError, "name cannot be blank")
    end

    it "raises ArgumentError when body is blank" do
      expect { responses.create(name: "Hello", body: "  ") }
        .to raise_error(ArgumentError, "body cannot be blank")
    end

    it "raises ServerError when API returns no responses key" do
      allow(connection).to receive(:request).and_return({})
      expect { responses.create(name: "Hello", body: "<p>Hi</p>") }
        .to raise_error(Missive::ServerError, "Response creation failed")
    end
  end

  describe "#update" do
    let(:updated) { { "id" => "resp-1", "name" => "New name", "body" => "<p>New</p>" } }

    it "PATCHes /responses/:id with attrs" do
      expected = { responses: { name: "New name" } }
      expect(connection).to receive(:request).with(:patch, "/responses/resp-1", body: expected).and_return({ responses: updated })

      result = responses.update(id: "resp-1", name: "New name")
      expect(result.id).to eq("resp-1")
      expect(result.name).to eq("New name")
    end

    it "raises ArgumentError when id is blank" do
      expect { responses.update(id: "") }.to raise_error(ArgumentError, "id cannot be blank")
    end

    it "raises ArgumentError when no attrs provided" do
      expect { responses.update(id: "resp-1") }.to raise_error(ArgumentError, "no attributes provided for update")
    end

    it "raises ServerError when API returns no responses key" do
      allow(connection).to receive(:request).and_return({})
      expect { responses.update(id: "resp-1", name: "X") }
        .to raise_error(Missive::ServerError, "Response update failed")
    end
  end

  describe "#delete" do
    it "DELETEs /responses/:id and returns true" do
      expect(connection).to receive(:request).with(:delete, "/responses/resp-1").and_return(nil)
      expect(responses.delete(id: "resp-1")).to eq(true)
    end

    it "raises ArgumentError when id is blank" do
      expect { responses.delete(id: nil) }.to raise_error(ArgumentError, "id cannot be blank")
    end

    it "surfaces NotFoundError" do
      allow(connection).to receive(:request).and_raise(Missive::NotFoundError.new("not found"))
      expect { responses.delete(id: "resp-1") }.to raise_error(Missive::NotFoundError)
    end
  end
end
