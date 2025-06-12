# frozen_string_literal: true

require "spec_helper"

RSpec.describe Missive::Resources::Drafts do
  let(:client) { Missive::Client.new(api_token: "test-token") }
  let(:drafts) { described_class.new(client) }
  let(:connection) { instance_double(Missive::Connection) }

  before do
    allow(client).to receive(:connection).and_return(connection)
  end

  describe "#initialize" do
    it "stores the client" do
      expect(drafts.instance_variable_get(:@client)).to eq(client)
    end
  end

  describe "#create" do
    let(:minimal_params) do
      {
        body: "Test message",
        to_fields: [{ address: "test@example.com" }],
        from_field: { address: "sender@example.com" }
      }
    end

    let(:response_data) do
      {
        "id" => "12345",
        "subject" => "Test",
        "body" => "Test message"
      }
    end

    context "with minimal payload" do
      it "returns Missive::Object" do
        allow(connection).to receive(:request).and_return(response_data)

        result = drafts.create(**minimal_params)

        expect(result).to be_a(Missive::Object)
        expect(result.id).to eq("12345")
      end

      it "POSTs correct JSON" do
        expected_payload = {
          drafts: {
            body: "Test message",
            to_fields: [{ address: "test@example.com" }],
            from_field: { address: "sender@example.com" }
          }
        }

        expect(connection).to receive(:request).with(
          :post,
          "/drafts",
          body: expected_payload
        ).and_return(response_data)

        drafts.create(**minimal_params)
      end
    end

    context "with subject" do
      it "includes subject in payload" do
        expected_payload = {
          drafts: {
            subject: "Test Subject",
            body: "Test message",
            to_fields: [{ address: "test@example.com" }],
            from_field: { address: "sender@example.com" }
          }
        }

        expect(connection).to receive(:request).with(
          :post,
          "/drafts",
          body: expected_payload
        ).and_return(response_data)

        drafts.create(**minimal_params, subject: "Test Subject")
      end
    end

    context "with attachments" do
      it "validates each attachment has valid content" do
        valid_attachments = [
          { text: "Plain text attachment" },
          { markdown: "**Bold** text" },
          { image_url: "https://example.com/image.png" },
          { fields: [{ key: "status", value: "active" }] }
        ]

        allow(connection).to receive(:request).and_return(response_data)

        expect do
          drafts.create(**minimal_params, attachments: valid_attachments)
        end.not_to raise_error
      end

      it "raises error for invalid attachments" do
        invalid_attachments = [
          { invalid_key: "value" }
        ]

        expect do
          drafts.create(**minimal_params, attachments: invalid_attachments)
        end.to raise_error(ArgumentError, /Each attachment must include at least one of/)
      end
    end

    context "with quote_previous_message" do
      it "includes the key in payload" do
        expected_payload = {
          drafts: {
            body: "Test message",
            to_fields: [{ address: "test@example.com" }],
            from_field: { address: "sender@example.com" },
            quote_previous_message: true
          }
        }

        expect(connection).to receive(:request).with(
          :post,
          "/drafts",
          body: expected_payload
        ).and_return(response_data)

        drafts.create(**minimal_params, quote_previous_message: true)
      end
    end

    context "validation errors" do
      it "raises error when body is missing" do
        expect do
          drafts.create(
            to_fields: [{ address: "test@example.com" }],
            from_field: { address: "sender@example.com" }
          )
        end.to raise_error(ArgumentError, /missing keyword: :?body/)
      end

      it "raises error when body is empty" do
        expect do
          drafts.create(
            body: "",
            to_fields: [{ address: "test@example.com" }],
            from_field: { address: "sender@example.com" }
          )
        end.to raise_error(ArgumentError, "body is required")
      end

      it "raises error when to_fields is missing" do
        expect do
          drafts.create(
            body: "Test",
            from_field: { address: "sender@example.com" }
          )
        end.to raise_error(ArgumentError, /missing keyword: :?to_fields/)
      end

      it "raises error when from_field is missing" do
        expect do
          drafts.create(
            body: "Test",
            to_fields: [{ address: "test@example.com" }]
          )
        end.to raise_error(ArgumentError, /missing keyword: :?from_field/)
      end

      it "raises error when both references and conversation are provided" do
        expect do
          drafts.create(
            **minimal_params,
            references: "ref-123",
            conversation: "conv-456"
          )
        end.to raise_error(ArgumentError, "Cannot pass both references and conversation (mutually exclusive)")
      end
    end

    context "server errors" do
      it "maps 400 response to Missive::ServerError" do
        allow(connection).to receive(:request).and_raise(
          Missive::ServerError.new("Bad Request")
        )

        expect do
          drafts.create(**minimal_params)
        end.to raise_error(Missive::ServerError)
      end
    end

    context "instrumentation" do
      it "calls the create method within instrumentation block" do
        allow(connection).to receive(:request).and_return(response_data)

        expected_payload = { drafts: { body: "Test message", to_fields: [{ address: "test@example.com" }],
                                       from_field: { address: "sender@example.com" } } }
        expect(connection).to receive(:request).with(:post, "/drafts", body: expected_payload)

        drafts.create(**minimal_params)
      end
    end
  end

  describe "#send_message" do
    let(:params) do
      {
        subject: "Test",
        body: "Test message",
        to_fields: [{ address: "test@example.com" }],
        from_field: { address: "sender@example.com" }
      }
    end

    it "sets send: true in payload" do
      expected_payload = {
        drafts: {
          subject: "Test",
          body: "Test message",
          to_fields: [{ address: "test@example.com" }],
          from_field: { address: "sender@example.com" },
          send: true
        }
      }

      expect(connection).to receive(:request).with(
        :post,
        "/drafts",
        body: expected_payload
      ).and_return({ "id" => "123" })

      drafts.send_message(**params)
    end

    it "calls the send_message method within instrumentation block" do
      allow(connection).to receive(:request).and_return({ "id" => "123" })

      expected_payload = { drafts: { subject: "Test", body: "Test message", to_fields: [{ address: "test@example.com" }],
                                     from_field: { address: "sender@example.com" }, send: true } }
      expect(connection).to receive(:request).with(:post, "/drafts", body: expected_payload)

      drafts.send_message(**params)
    end
  end
end
