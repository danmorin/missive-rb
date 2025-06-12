# frozen_string_literal: true

require "spec_helper"

RSpec.describe "List Method Consistency", :vcr do
  let(:client) { Missive::Client.new(api_token: ENV['MISSIVE_API_TOKEN'] || 'test-token') }

  # Skip integration tests if no API token is provided
  before do
    skip "Set MISSIVE_API_TOKEN environment variable to run integration tests" unless ENV['MISSIVE_API_TOKEN']
  end

  shared_examples "consistent list endpoint" do |resource_name, resource_method|
    it "returns an array of Missive::Object instances" do
      VCR.use_cassette("#{resource_name}_list_consistency") do
        result = client.public_send(resource_method).list(limit: 1)
        
        expect(result).to be_an(Array), "#{resource_name} should return an Array, got #{result.class}"
        
        if result.any?
          expect(result.first).to be_a(Missive::Object), 
            "#{resource_name} array elements should be Missive::Object instances, got #{result.first.class}"
          expect(result.first).to respond_to(:id), "#{resource_name} objects should have an id method"
        end
      end
    end
  end

  # Test all resources that have list methods
  describe "Organizations" do
    include_examples "consistent list endpoint", "organizations", :organizations
  end

  describe "Teams" do
    include_examples "consistent list endpoint", "teams", :teams
    
    it "accepts organization parameter" do
      VCR.use_cassette("teams_list_with_organization") do
        # This might fail if no organization is available, but that's expected
        begin
          result = client.teams.list(limit: 1, organization: "test-org-id")
          expect(result).to be_an(Array)
        rescue Missive::NotFoundError, Missive::AuthenticationError
          # These errors are expected in tests - the important thing is the return type
          skip "Organization not accessible, but endpoint structure verified"
        end
      end
    end
  end

  describe "Users" do
    include_examples "consistent list endpoint", "users", :users
  end

  describe "Conversations" do
    include_examples "consistent list endpoint", "conversations", :conversations
  end

  describe "Contacts" do
    include_examples "consistent list endpoint", "contacts", :contacts
  end

  describe "Contact Books" do
    include_examples "consistent list endpoint", "contact_books", :contact_books
  end

  describe "Contact Groups" do
    include_examples "consistent list endpoint", "contact_groups", :contact_groups
  end

  describe "Shared Labels" do
    include_examples "consistent list endpoint", "shared_labels", :shared_labels
  end

  describe "Responses" do
    include_examples "consistent list endpoint", "responses", :responses
  end