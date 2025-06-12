# frozen_string_literal: true

require "rack/test"

RSpec.describe Missive::WebhookServer do
  include Rack::Test::Methods

  let(:signature_secret) { "test-secret" }
  let(:base_app) { ->(_env) { [200, {}, ["OK"]] } }
  let(:middleware) { described_class.new(base_app, signature_secret: signature_secret) }

  def app
    middleware
  end

  describe "#initialize" do
    it "sets the app and signature_secret" do
      expect(middleware.app).to eq(base_app)
      expect(middleware.signature_secret).to eq(signature_secret)
    end

    it "raises ArgumentError for blank signature_secret" do
      expect do
        described_class.new(base_app, signature_secret: "")
      end.to raise_error(ArgumentError, "signature_secret cannot be blank")

      expect do
        described_class.new(base_app, signature_secret: nil)
      end.to raise_error(ArgumentError, "signature_secret cannot be blank")

      expect do
        described_class.new(base_app, signature_secret: "   ")
      end.to raise_error(ArgumentError, "signature_secret cannot be blank")
    end
  end

  describe "#call" do
    let(:webhook_data) { { event: "new_comment", data: { id: "123" } } }
    let(:body) { JSON.generate(webhook_data) }
    let(:valid_signature) { Missive::Signature.generate(body, signature_secret) }

    context "with valid signature" do
      it "passes through to the app and sets webhook data" do
        post "/", body, { "HTTP_X_HOOK_SIGNATURE" => valid_signature }

        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq("OK")

        # Check that webhook data was set in env
        webhook_env_data = last_request.env["missive.webhook"]
        expect(webhook_env_data).to eq(webhook_data)
      end

      it "handles empty body" do
        empty_signature = Missive::Signature.generate("", signature_secret)
        post "/", "", { "HTTP_X_HOOK_SIGNATURE" => empty_signature }

        expect(last_response.status).to eq(200)
      end

      it "handles invalid JSON gracefully" do
        invalid_json = "{ invalid json"
        invalid_signature = Missive::Signature.generate(invalid_json, signature_secret)

        post "/", invalid_json, { "HTTP_X_HOOK_SIGNATURE" => invalid_signature }

        expect(last_response.status).to eq(200)
        expect(last_request.env["missive.webhook"]).to be_nil
      end
    end

    context "with invalid signature" do
      it "returns 403 for wrong signature" do
        wrong_signature = "sha256=wrong"
        post "/", body, { "HTTP_X_HOOK_SIGNATURE" => wrong_signature }

        expect(last_response.status).to eq(403)
        expect(last_response.content_type).to eq("application/json")

        response_data = JSON.parse(last_response.body)
        expect(response_data["error"]).to eq("invalid_signature")
      end

      it "returns 403 for missing signature" do
        post "/", body

        expect(last_response.status).to eq(403)
        expect(last_response.content_type).to eq("application/json")

        response_data = JSON.parse(last_response.body)
        expect(response_data["error"]).to eq("invalid_signature")
      end

      it "returns 403 for empty signature" do
        post "/", body, { "HTTP_X_HOOK_SIGNATURE" => "" }

        expect(last_response.status).to eq(403)
        expect(last_response.content_type).to eq("application/json")

        response_data = JSON.parse(last_response.body)
        expect(response_data["error"]).to eq("invalid_signature")
      end
    end

    context "when app raises an error" do
      let(:error_app) { ->(_env) { raise StandardError, "App error" } }
      let(:error_middleware) { described_class.new(error_app, signature_secret: signature_secret) }

      def app
        error_middleware
      end

      it "lets the error propagate after validation" do
        expect do
          post "/", body, { "HTTP_X_HOOK_SIGNATURE" => valid_signature }
        end.to raise_error(StandardError, "App error")
      end
    end
  end

  describe ".mount" do
    let(:path) { "/webhooks" }
    let(:mounted_app) { described_class.mount(path, signature_secret) }

    it "returns a Rack::Builder" do
      expect(mounted_app).to be_a(Rack::Builder)
    end

    it "creates a working webhook endpoint" do
      webhook_data = { event: "test" }
      body = JSON.generate(webhook_data)
      signature = Missive::Signature.generate(body, signature_secret)

      request = Rack::MockRequest.new(mounted_app)
      response = request.post(path, input: body, "HTTP_X_HOOK_SIGNATURE" => signature)

      expect(response.status).to eq(200)
      response_data = JSON.parse(response.body)
      expect(response_data["status"]).to eq("ok")
    end

    it "rejects invalid signatures in mounted app" do
      body = JSON.generate({ event: "test" })

      request = Rack::MockRequest.new(mounted_app)
      response = request.post(path, input: body, "HTTP_X_HOOK_SIGNATURE" => "invalid")

      expect(response.status).to eq(403)
      response_data = JSON.parse(response.body)
      expect(response_data["error"]).to eq("invalid_signature")
    end
  end
end
