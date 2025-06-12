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
      it "validates each attachment has base64_data and filename" do
        valid_attachments = [
          { base64_data: "iVBORw0KGgoAAAANS...", filename: "logo.png" },
          { base64_data: "R0lGODlhAQABAIAAAP///...", filename: "image.gif" }
        ]

        allow(connection).to receive(:request).and_return(response_data)

        expect do
          drafts.create(**minimal_params, attachments: valid_attachments)
        end.not_to raise_error
      end

      it "raises error for attachments missing base64_data" do
        invalid_attachments = [
          { filename: "logo.png" }
        ]

        expect do
          drafts.create(**minimal_params, attachments: invalid_attachments)
        end.to raise_error(ArgumentError, /must include base64_data/)
      end

      it "raises error for attachments missing filename" do
        invalid_attachments = [
          { base64_data: "iVBORw0KGgoAAAANS..." }
        ]

        expect do
          drafts.create(**minimal_params, attachments: invalid_attachments)
        end.to raise_error(ArgumentError, /must include filename/)
      end

      it "raises error for too many attachments" do
        many_attachments = Array.new(26) do |i|
          { base64_data: "data#{i}", filename: "file#{i}.txt" }
        end

        expect do
          drafts.create(**minimal_params, attachments: many_attachments)
        end.to raise_error(ArgumentError, /Maximum 25 attachments allowed/)
      end

      it "raises error for non-array attachments" do
        expect do
          drafts.create(**minimal_params, attachments: "not an array")
        end.to raise_error(ArgumentError, /attachments must be an array/)
      end
    end

    context "with advanced parameters" do
      it "includes cc_fields and bcc_fields" do
        expected_payload = {
          drafts: {
            body: "Test message",
            to_fields: [{ address: "test@example.com" }],
            from_field: { address: "sender@example.com" },
            cc_fields: [{ address: "cc@example.com", name: "CC Person" }],
            bcc_fields: [{ address: "bcc@example.com" }]
          }
        }

        expect(connection).to receive(:request).with(
          :post,
          "/drafts",
          body: expected_payload
        ).and_return(response_data)

        drafts.create(
          **minimal_params,
          cc_fields: [{ address: "cc@example.com", name: "CC Person" }],
          bcc_fields: [{ address: "bcc@example.com" }]
        )
      end

      it "includes team and organization parameters" do
        expected_payload = {
          drafts: {
            body: "Test message",
            to_fields: [{ address: "test@example.com" }],
            from_field: { address: "sender@example.com" },
            team: "team-123",
            organization: "org-456",
            add_users: ["user-789"],
            add_assignees: ["user-abc"]
          }
        }

        expect(connection).to receive(:request).with(
          :post,
          "/drafts",
          body: expected_payload
        ).and_return(response_data)

        drafts.create(
          **minimal_params,
          team: "team-123",
          organization: "org-456",
          add_users: ["user-789"],
          add_assignees: ["user-abc"]
        )
      end

      it "includes conversation management parameters" do
        expected_payload = {
          drafts: {
            body: "Test message",
            to_fields: [{ address: "test@example.com" }],
            from_field: { address: "sender@example.com" },
            conversation_subject: "New Subject",
            conversation_color: "#ff0000",
            add_to_inbox: true,
            close: false
          }
        }

        expect(connection).to receive(:request).with(
          :post,
          "/drafts",
          body: expected_payload
        ).and_return(response_data)

        drafts.create(
          **minimal_params,
          conversation_subject: "New Subject",
          conversation_color: "#ff0000",
          add_to_inbox: true,
          close: false
        )
      end

      it "includes WhatsApp template parameters" do
        expected_payload = {
          drafts: {
            body: "Hello {{1}}, welcome to {{2}}!",
            to_fields: [{ phone_number: "+18005551234" }],
            from_field: { phone_number: "+18005559999", type: "whatsapp" },
            external_response_id: "474808552386201",
            external_response_variables: { "1" => "John", "2" => "Acme Corp" }
          }
        }

        expect(connection).to receive(:request).with(
          :post,
          "/drafts",
          body: expected_payload
        ).and_return(response_data)

        drafts.create(
          body: "Hello {{1}}, welcome to {{2}}!",
          to_fields: [{ phone_number: "+18005551234" }],
          from_field: { phone_number: "+18005559999", type: "whatsapp" },
          external_response_id: "474808552386201",
          external_response_variables: { "1" => "John", "2" => "Acme Corp" }
        )
      end

      it "includes references as array" do
        expected_payload = {
          drafts: {
            body: "Test message",
            to_fields: [{ address: "test@example.com" }],
            from_field: { address: "sender@example.com" },
            references: ["<ref-123>", "<ref-456>"]
          }
        }

        expect(connection).to receive(:request).with(
          :post,
          "/drafts",
          body: expected_payload
        ).and_return(response_data)

        drafts.create(
          **minimal_params,
          references: ["<ref-123>", "<ref-456>"]
        )
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
            references: ["ref-123"],
            conversation: "conv-456"
          )
        end.to raise_error(ArgumentError, "Cannot pass both references and conversation (mutually exclusive)")
      end

      it "raises error when references is not an array" do
        expect do
          drafts.create(
            **minimal_params,
            references: "ref-123"
          )
        end.to raise_error(ArgumentError, "references must be an array")
      end

      it "raises error when send and send_at are both provided" do
        expect do
          drafts.create(
            **minimal_params,
            send: true,
            send_at: Time.now.to_i + 3600
          )
        end.to raise_error(ArgumentError, "Cannot use both send: true and send_at (mutually exclusive)")
      end

      it "raises error when auto_followup without send_at" do
        expect do
          drafts.create(
            **minimal_params,
            auto_followup: true
          )
        end.to raise_error(ArgumentError, "auto_followup requires send_at to be specified")
      end

      it "raises error when send_at is in the past" do
        expect do
          drafts.create(
            **minimal_params,
            send_at: Time.now.to_i - 3600
          )
        end.to raise_error(ArgumentError, "send_at must be in the future")
      end

      it "raises error when add_users without organization" do
        expect do
          drafts.create(
            **minimal_params,
            add_users: ["user-123"]
          )
        end.to raise_error(ArgumentError, "organization is required when using add_users or add_assignees")
      end

      it "raises error when add_assignees without organization" do
        expect do
          drafts.create(
            **minimal_params,
            add_assignees: ["user-123"]
          )
        end.to raise_error(ArgumentError, "organization is required when using add_users or add_assignees")
      end

      it "raises error when add_to_team_inbox without team" do
        expect do
          drafts.create(
            **minimal_params,
            add_to_team_inbox: true
          )
        end.to raise_error(ArgumentError, "team is required when using add_to_team_inbox")
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

    context "response handling" do
      it "handles response with drafts key" do
        response_with_drafts = { "drafts" => response_data }
        allow(connection).to receive(:request).and_return(response_with_drafts)

        result = drafts.create(**minimal_params)

        expect(result).to be_a(Missive::Object)
        expect(result.id).to eq("12345")
      end

      it "raises error when draft not created" do
        allow(connection).to receive(:request).and_return(nil)

        expect do
          drafts.create(**minimal_params)
        end.to raise_error(Missive::Error, "Draft not created")
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
  end

  describe "#schedule_message" do
    let(:params) do
      {
        body: "Test message",
        to_fields: [{ address: "test@example.com" }],
        from_field: { address: "sender@example.com" }
      }
    end

    let(:send_time) { Time.now.to_i + 3600 }

    it "sets send_at in payload" do
      expected_payload = {
        drafts: {
          body: "Test message",
          to_fields: [{ address: "test@example.com" }],
          from_field: { address: "sender@example.com" },
          send_at: send_time,
          auto_followup: false
        }
      }

      expect(connection).to receive(:request).with(
        :post,
        "/drafts",
        body: expected_payload
      ).and_return({ "id" => "123" })

      drafts.schedule_message(send_at: send_time, **params)
    end

    it "includes auto_followup when specified" do
      expected_payload = {
        drafts: {
          body: "Test message",
          to_fields: [{ address: "test@example.com" }],
          from_field: { address: "sender@example.com" },
          send_at: send_time,
          auto_followup: true
        }
      }

      expect(connection).to receive(:request).with(
        :post,
        "/drafts",
        body: expected_payload
      ).and_return({ "id" => "123" })

      drafts.schedule_message(send_at: send_time, auto_followup: true, **params)
    end
  end
end
