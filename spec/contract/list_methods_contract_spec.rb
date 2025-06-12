# frozen_string_literal: true

require "spec_helper"

RSpec.describe "List Methods Contract" do
  # Test that all resources with list methods follow the same contract
  describe "Resource consistency" do
    # Resources with standard list methods (limit, offset)
    standard_resources = [
      [Missive::Resources::Organizations, "organizations"],
      [Missive::Resources::Teams, "teams"],
      [Missive::Resources::Users, "users"],
      [Missive::Resources::ContactBooks, "contact_books"],
      [Missive::Resources::SharedLabels, "shared_labels"],
      [Missive::Resources::Responses, "responses"]
    ]

    standard_resources.each do |resource_class, data_key|
      context "#{resource_class}" do
        include_examples "a resource with consistent list method", resource_class, data_key
      end
    end

    # Resources with special parameter requirements
    context "Missive::Resources::Contacts" do
      include_examples "a resource with consistent list method", Missive::Resources::Contacts, "contacts"
    end

    # ContactGroups requires special parameters
    context "Missive::Resources::ContactGroups" do
      let(:client) { Missive::Client.new(api_token: "test-token") }
      let(:connection) { instance_double(Missive::Connection) }
      let(:resource) { Missive::Resources::ContactGroups.new(client) }

      before do
        allow(client).to receive(:connection).and_return(connection)
      end

      it "returns an Array when called with required parameters" do
        mock_response = {
          "contact_groups" => [
            { "id" => "group-1", "name" => "Test Group" }
          ]
        }
        allow(connection).to receive(:request).and_return(mock_response)
        
        result = resource.list(contact_book: "book-123", kind: "group", limit: 1)
        expect(result).to be_an(Array)
        expect(result.first).to be_a(Missive::Object) if result.any?
      end
    end

    # Conversations uses different pagination (until_cursor instead of offset)
    context "Missive::Resources::Conversations" do
      let(:client) { Missive::Client.new(api_token: "test-token") }
      let(:connection) { instance_double(Missive::Connection) }
      let(:resource) { Missive::Resources::Conversations.new(client) }

      before do
        allow(client).to receive(:connection).and_return(connection)
      end

      it "returns an Array" do
        mock_response = {
          "conversations" => [
            { "id" => "conv-1", "subject" => "Test Conversation" }
          ]
        }
        allow(connection).to receive(:request).and_return(mock_response)
        
        result = resource.list(limit: 1)
        expect(result).to be_an(Array)
        expect(result.first).to be_a(Missive::Object) if result.any?
      end
    end
  end

  describe "Return type validation" do
    let(:client) { Missive::Client.new(api_token: "test-token") }
    let(:connection) { instance_double(Missive::Connection) }

    before do
      allow(client).to receive(:connection).and_return(connection)
    end

    it "standard resources return Arrays" do
      standard_resources = [
        client.organizations,
        client.teams,
        client.users,
        client.contact_books,
        client.shared_labels,
        client.responses
      ]

      standard_resources.each do |resource|
        # Mock a response with empty data
        allow(connection).to receive(:request).and_return({})

        result = resource.list(limit: 1)
        expect(result).to be_an(Array), "#{resource.class} should return Array from list()"
      end
    end

    it "contacts resource returns Array" do
      allow(connection).to receive(:request).and_return({})
      result = client.contacts.list(limit: 1)
      expect(result).to be_an(Array)
    end

    it "conversations resource returns Array" do
      allow(connection).to receive(:request).and_return({})
      result = client.conversations.list(limit: 1)
      expect(result).to be_an(Array)
    end
  end

  describe "Core contract compliance" do
    it "all resources with list methods return Arrays consistently" do
      # This test just ensures our fixes work - all list methods should return arrays
      client = Missive::Client.new(api_token: "test-token")
      connection = instance_double(Missive::Connection)
      allow(client).to receive(:connection).and_return(connection)
      allow(connection).to receive(:request).and_return({})

      # Test each resource individually with appropriate parameters
      expect(client.organizations.list(limit: 1)).to be_an(Array)
      expect(client.teams.list(limit: 1)).to be_an(Array)
      expect(client.users.list(limit: 1)).to be_an(Array)
      expect(client.contact_books.list(limit: 1)).to be_an(Array)
      expect(client.shared_labels.list(limit: 1)).to be_an(Array)
      expect(client.responses.list(limit: 1)).to be_an(Array)
      expect(client.contacts.list(limit: 1)).to be_an(Array)
      expect(client.conversations.list(limit: 1)).to be_an(Array)
    end
  end
end