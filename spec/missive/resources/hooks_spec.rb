# frozen_string_literal: true

RSpec.describe Missive::Resources::Hooks do
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

  describe "#create" do
    let(:hook_type) { "new_comment" }
    let(:hook_url) { "https://example.com/webhook" }
    let(:hook_response) { { hooks: { id: "hook-123", type: hook_type, url: hook_url } } }

    context "with instrumentation" do
      it "instruments the create request" do
        notifications = []
        ActiveSupport::Notifications.subscribe("missive.hooks.create") do |_name, _start, _finish, _id, payload|
          notifications << payload
        end

        expect(connection).to receive(:request).with(
          :post,
          "/hooks",
          body: { hooks: { type: hook_type, url: hook_url } }
        ).and_return(hook_response)

        result = subject.create(type: hook_type, url: hook_url)
        expect(notifications).not_to be_empty
        expect(notifications.last[:body][:hooks][:type]).to eq(hook_type)
        expect(result).to be_a(Missive::Object)
      end
    end

    context "with valid parameters" do
      it "creates a basic webhook" do
        expect(connection).to receive(:request).with(
          :post,
          "/hooks",
          body: {
            hooks: {
              type: hook_type,
              url: hook_url
            }
          }
        ).and_return(hook_response)

        result = subject.create(type: hook_type, url: hook_url)

        expect(result).to be_a(Missive::Object)
        expect(result.id).to eq("hook-123")
        expect(result.type).to eq(hook_type)
        expect(result.url).to eq(hook_url)
      end

      it "creates a webhook with filters" do
        mailbox = "inbox-123"
        teams = %w[team-1 team-2]

        expect(connection).to receive(:request).with(
          :post,
          "/hooks",
          body: {
            hooks: {
              type: hook_type,
              url: hook_url,
              mailbox: mailbox,
              teams: teams
            }
          }
        ).and_return(hook_response)

        result = subject.create(
          type: hook_type,
          url: hook_url,
          mailbox: mailbox,
          teams: teams
        )

        expect(result).to be_a(Missive::Object)
      end

      it "accepts all valid webhook types" do
        described_class::VALID_TYPES.each do |valid_type|
          expect(connection).to receive(:request).and_return(hook_response)

          result = subject.create(type: valid_type, url: hook_url)
          expect(result).to be_a(Missive::Object)
        end
      end
    end

    context "with validation errors" do
      it "raises ArgumentError for blank type" do
        expect do
          subject.create(type: "", url: hook_url)
        end.to raise_error(ArgumentError, "type cannot be blank")

        expect do
          subject.create(type: nil, url: hook_url)
        end.to raise_error(ArgumentError, "type cannot be blank")

        expect do
          subject.create(type: "   ", url: hook_url)
        end.to raise_error(ArgumentError, "type cannot be blank")
      end

      it "raises ArgumentError for invalid type" do
        expect do
          subject.create(type: "invalid_type", url: hook_url)
        end.to raise_error(ArgumentError, /type must be one of:/)
      end

      it "raises ArgumentError for blank url" do
        expect do
          subject.create(type: hook_type, url: "")
        end.to raise_error(ArgumentError, "url cannot be blank")

        expect do
          subject.create(type: hook_type, url: nil)
        end.to raise_error(ArgumentError, "url cannot be blank")

        expect do
          subject.create(type: hook_type, url: "   ")
        end.to raise_error(ArgumentError, "url cannot be blank")
      end

      it "converts type to string for validation" do
        expect(connection).to receive(:request).with(
          :post,
          "/hooks",
          body: {
            hooks: {
              type: "new_comment",
              url: hook_url
            }
          }
        ).and_return(hook_response)

        # Test that symbols are converted to strings
        result = subject.create(type: :new_comment, url: hook_url)
        expect(result).to be_a(Missive::Object)
      end

      it "handles empty filters hash" do
        expect(connection).to receive(:request).with(
          :post,
          "/hooks",
          body: {
            hooks: {
              type: hook_type,
              url: hook_url
            }
          }
        ).and_return(hook_response)

        # Test that empty filters don't get merged
        result = subject.create(type: hook_type, url: hook_url, **{})
        expect(result).to be_a(Missive::Object)
      end
    end

    it "handles server errors" do
      expect(connection).to receive(:request).and_return({ hooks: nil })

      expect do
        subject.create(type: hook_type, url: hook_url)
      end.to raise_error(Missive::ServerError, "Hook creation failed")
    end
  end

  describe "#delete" do
    let(:hook_id) { "hook-123" }

    context "with instrumentation" do
      it "instruments the delete request" do
        notifications = []
        ActiveSupport::Notifications.subscribe("missive.hooks.delete") do |_name, _start, _finish, _id, payload|
          notifications << payload
        end

        expect(connection).to receive(:request).with(
          :delete,
          "/hooks/hook-123"
        ).and_return(true)

        result = subject.delete(id: hook_id)
        expect(notifications).not_to be_empty
        expect(notifications.last[:id]).to eq(hook_id)
        expect(result).to be true
      end
    end

    context "with valid parameters" do
      it "deletes a webhook" do
        expect(connection).to receive(:request).with(
          :delete,
          "/hooks/hook-123"
        ).and_return(true)

        result = subject.delete(id: hook_id)

        expect(result).to be true
      end
    end

    context "with validation errors" do
      it "raises ArgumentError for blank id" do
        expect do
          subject.delete(id: "")
        end.to raise_error(ArgumentError, "id cannot be blank")

        expect do
          subject.delete(id: nil)
        end.to raise_error(ArgumentError, "id cannot be blank")

        expect do
          subject.delete(id: "   ")
        end.to raise_error(ArgumentError, "id cannot be blank")
      end
    end

    it "propagates NotFoundError for 404" do
      expect(connection).to receive(:request).and_raise(Missive::NotFoundError, "Hook not found")

      expect do
        subject.delete(id: hook_id)
      end.to raise_error(Missive::NotFoundError, "Hook not found")
    end
  end
end
