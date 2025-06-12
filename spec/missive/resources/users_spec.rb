# frozen_string_literal: true

RSpec.describe Missive::Resources::Users do
  let(:client) { double("Client") }
  let(:connection) { double("Connection") }
  subject { described_class.new(client) }

  before do
    allow(client).to receive(:connection).and_return(connection)
  end

  describe "#initialize" do
    it "sets the client" do
      expect(subject.client).to eq(client)
    end
  end

  describe "#list" do
    include_examples "a list endpoint with limit and offset", :users, "/users"

    context "with organization parameter" do
      let(:organization) { "org-123" }
      let(:users_response) do
        {
          users: [
            { id: "user-1", email: "user1@example.com" },
            { id: "user-2", email: "user2@example.com" }
          ],
          offset: 0,
          limit: 50
        }
      end

      it "includes organization in request params" do
        notifications = []
        ActiveSupport::Notifications.subscribe("missive.users.list") do |_name, _start, _finish, _id, payload|
          notifications << payload
        end

        expect(connection).to receive(:request).with(
          :get,
          "/users",
          params: { limit: 50, offset: 0, organization: organization }
        ).and_return(users_response)

        result = subject.list(organization: organization)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.first).to be_a(Missive::Object)
        expect(result.first.id).to eq("user-1")
        expect(result.first.email).to eq("user1@example.com")
        expect(notifications).not_to be_empty
        expect(notifications.last[:params]).to eq({ limit: 50, offset: 0, organization: organization })
      end
    end

    it "instruments the request" do
      notifications = []
      ActiveSupport::Notifications.subscribe("missive.users.list") do |_name, _start, _finish, _id, payload|
        notifications << payload
      end

      expect(connection).to receive(:request).and_return({ users: [] })

      subject.list
      expect(notifications).not_to be_empty
      expect(notifications.last[:params]).to eq({ limit: 50, offset: 0 })
    end
  end

  describe "#each_item" do
    include_examples "a paginated list endpoint with limit", "/users", :users

    context "with organization parameter" do
      it "passes organization to paginator" do
        organization = "org-123"
        expected_params = { limit: 50, organization: organization }

        expect(Missive::Paginator).to receive(:each_item).with(
          path: "/users",
          client: client,
          params: expected_params,
          data_key: :users
        )

        subject.each_item(organization: organization) { |_| } # rubocop:disable Lint/EmptyBlock
      end
    end
  end
end
