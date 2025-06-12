# frozen_string_literal: true

# Contract tests to ensure all list methods follow the same pattern
RSpec.shared_examples "a resource with consistent list method" do |resource_class, data_key|
  let(:client) { Missive::Client.new(api_token: "test-token") }
  let(:connection) { instance_double(Missive::Connection) }
  let(:resource) { resource_class.new(client) }

  before do
    allow(client).to receive(:connection).and_return(connection)
  end

  describe "#list contract" do
    let(:mock_response) do
      {
        data_key => [
          { "id" => "test-1", "name" => "Test Item 1" },
          { "id" => "test-2", "name" => "Test Item 2" }
        ],
        "offset" => 0,
        "limit" => 50
      }
    end

    it "returns an Array" do
      allow(connection).to receive(:request).and_return(mock_response)
      
      result = resource.list(limit: 2)
      expect(result).to be_an(Array), "#{resource_class} list() should return Array"
    end

    it "returns Missive::Object instances" do
      allow(connection).to receive(:request).and_return(mock_response)
      
      result = resource.list(limit: 2)
      expect(result.length).to eq(2)
      expect(result.first).to be_a(Missive::Object), "#{resource_class} should return Missive::Object instances"
      expect(result.first.id).to eq("test-1")
      expect(result.first.name).to eq("Test Item 1")
    end

    it "handles empty response gracefully" do
      empty_response = { data_key => [], "offset" => 0, "limit" => 50 }
      allow(connection).to receive(:request).and_return(empty_response)
      
      result = resource.list(limit: 2)
      expect(result).to be_an(Array)
      expect(result).to be_empty
    end

    it "handles missing data key gracefully" do
      response_without_data = { "offset" => 0, "limit" => 50 }
      allow(connection).to receive(:request).and_return(response_without_data)
      
      result = resource.list(limit: 2)
      expect(result).to be_an(Array)
      expect(result).to be_empty
    end
  end
end