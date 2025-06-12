# frozen_string_literal: true

require "spec_helper"

RSpec.describe Missive::Resources::Organizations do
  let(:client) { Missive::Client.new(api_token: "test-token") }
  let(:organizations) { described_class.new(client) }
  let(:connection) { instance_double(Missive::Connection) }
  subject { organizations }

  before do
    allow(client).to receive(:connection).and_return(connection)
  end

  describe "#initialize" do
    it "stores the client" do
      expect(organizations.instance_variable_get(:@client)).to eq(client)
    end
  end

  describe "#list" do
    let(:response_data) do
      {
        "organizations" => [
          { "id" => "org-1", "name" => "Acme Corp" },
          { "id" => "org-2", "name" => "Global Inc" }
        ],
        "offset" => 0,
        "limit" => 50
      }
    end

    it "sends GET request with default parameters" do
      expect(connection).to receive(:request).with(
        :get,
        "/organizations",
        params: { limit: 50, offset: 0 }
      ).and_return(response_data)

      organizations.list
    end

    it_behaves_like "a list endpoint", "organizations", "/organizations"
  end

  describe "#each_item" do
    it_behaves_like "a paginated list endpoint", "/organizations", :organizations

    it "yields Missive::Object instances" do
      # Mock the Paginator to yield raw data, which should be converted to Missive::Object
      allow(Missive::Paginator).to receive(:each_item).with(
        path: "/organizations",
        client: client,
        params: { limit: 50 },
        data_key: :organizations
      ) do |&block|
        # Simulate what Paginator.each_item does - it yields raw hash data
        # which our each_item method should convert to Missive::Object
        block.call({ "id" => "org-1", "name" => "Test Org" })
      end

      yielded_items = []
      organizations.each_item { |item| yielded_items << item }

      expect(yielded_items.length).to eq(1)
      expect(yielded_items.first).to be_a(Missive::Object)
      expect(yielded_items.first.id).to eq("org-1")
    end
  end
end
