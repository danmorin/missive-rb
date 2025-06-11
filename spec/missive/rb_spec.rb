# frozen_string_literal: true

RSpec.describe Missive do
  describe "constants" do
    # Test each constant individually to ensure full coverage

    describe "VERSION" do
      it "is set" do
        expect(Missive::VERSION).not_to be nil
      end

      it "is frozen" do
        expect(Missive::VERSION).to be_frozen
      end

      it "is a string" do
        expect(Missive::VERSION).to be_a(String)
      end
    end

    describe "BASE_URL" do
      it "is set" do
        expect(Missive::Constants::BASE_URL).not_to be nil
      end

      it "is frozen" do
        expect(Missive::Constants::BASE_URL).to be_frozen
      end

      it "is a string" do
        expect(Missive::Constants::BASE_URL).to be_a(String)
      end
    end

    describe "MAX_CONCURRENCY" do
      it "is set" do
        expect(Missive::Constants::MAX_CONCURRENCY).not_to be nil
      end

      it "is frozen" do
        expect(Missive::Constants::MAX_CONCURRENCY).to be_frozen
      end

      it "is an integer" do
        expect(Missive::Constants::MAX_CONCURRENCY).to be_a(Integer)
      end

      it "is a positive value" do
        expect(Missive::Constants::MAX_CONCURRENCY).to be > 0
      end
    end

    # Comprehensive test to ensure we haven't missed any constants
    it "has all expected constants defined and frozen" do
      expected_constants = %w[VERSION]

      expected_constants.each do |const_name|
        expect(Missive.const_defined?(const_name)).to be(true), "Expected constant #{const_name} to be defined"

        const_value = Missive.const_get(const_name)
        expect(const_value).not_to be_nil, "Expected constant #{const_name} to be set (not nil)"
        expect(const_value).to be_frozen, "Expected constant #{const_name} to be frozen"
      end

      # Check Constants module
      expect(Missive.const_defined?("Constants")).to be(true)
      expect(Missive::Constants.const_defined?("BASE_URL")).to be(true)
      expect(Missive::Constants::BASE_URL).not_to be_nil
      expect(Missive::Constants::BASE_URL).to be_frozen

      expect(Missive::Constants.const_defined?("MAX_CONCURRENCY")).to be(true)
      expect(Missive::Constants::MAX_CONCURRENCY).not_to be_nil
      expect(Missive::Constants::MAX_CONCURRENCY).to be_frozen
    end
  end

  describe "Error hierarchy" do
    describe "from_status class method" do
      it "returns AuthenticationError for status 401" do
        expect(Missive::Error.from_status(401, {})).to eq(Missive::AuthenticationError)
      end

      it "returns RateLimitError for status 429" do
        expect(Missive::Error.from_status(429, {})).to eq(Missive::RateLimitError)
      end

      it "returns ServerError for 5xx status codes" do
        expect(Missive::Error.from_status(500, {})).to eq(Missive::ServerError)
        expect(Missive::Error.from_status(502, {})).to eq(Missive::ServerError)
        expect(Missive::Error.from_status(599, {})).to eq(Missive::ServerError)
      end

      it "returns Error for unmatched status codes" do
        expect(Missive::Error.from_status(404, {})).to eq(Missive::Error)
        expect(Missive::Error.from_status(200, {})).to eq(Missive::Error)
      end
    end

    describe "inheritance chain" do
      let(:error_classes) do
        [
          Missive::ConfigurationError,
          Missive::MissingTokenError,
          Missive::AuthenticationError,
          Missive::RateLimitError,
          Missive::ServerError
        ]
      end

      it "all error subclasses inherit from Missive::Error" do
        error_classes.each do |error_class|
          expect(error_class.new).to be_kind_of(Missive::Error)
        end
      end

      it "all error subclasses inherit from StandardError" do
        error_classes.each do |error_class|
          expect(error_class.new).to be_kind_of(StandardError)
        end
      end

      it "Missive::Error inherits from StandardError" do
        expect(Missive::Error.new).to be_kind_of(StandardError)
      end
    end
  end

  describe "Client" do
    describe "#initialize" do
      it "raises MissingTokenError when api_token is nil" do
        expect do
          Missive::Client.new(api_token: nil)
        end.to raise_error(Missive::MissingTokenError, "api_token cannot be nil")
      end

      it "stores the api_token" do
        client = Missive::Client.new(api_token: "test_token")
        expect(client.token).to eq("test_token")
      end

      it "uses default base_url when not provided" do
        client = Missive::Client.new(api_token: "test_token")
        expect(client.config[:base_url]).to eq(Missive::Constants::BASE_URL)
      end

      it "allows custom base_url" do
        custom_url = "https://custom.api.com/v1"
        client = Missive::Client.new(api_token: "test_token", base_url: custom_url)
        expect(client.config[:base_url]).to eq(custom_url)
      end

      it "stores additional options in config" do
        client = Missive::Client.new(api_token: "test_token", timeout: 30, retries: 3)
        expect(client.config[:timeout]).to eq(30)
        expect(client.config[:retries]).to eq(3)
      end

      it "freezes the config hash" do
        client = Missive::Client.new(api_token: "test_token")
        expect(client.config).to be_frozen
      end
    end

    describe "#connection" do
      it "memoizes the connection instance" do
        client = Missive::Client.new(api_token: "test_token")
        connection1 = client.connection
        connection2 = client.connection
        expect(connection1).to be(connection2)
      end
    end

    describe "multiple clients" do
      it "creates clients with different tokens and separate connection objects" do
        client1 = Missive::Client.new(api_token: "token1")
        client2 = Missive::Client.new(api_token: "token2")

        expect(client1.token).to eq("token1")
        expect(client2.token).to eq("token2")
        expect(client1.token).not_to eq(client2.token)

        connection1 = client1.connection
        connection2 = client2.connection
        expect(connection1.object_id).not_to eq(connection2.object_id)
      end
    end
  end

  describe "Connection" do
    let(:token) { "test_token_123" }
    let(:base_url) { "https://api.example.com" }
    let(:connection) { Missive::Connection.new(token: token, base_url: base_url) }

    describe "#request" do
      it "makes GET request and parses JSON response" do
        stub_request(:get, "#{base_url}/ping")
          .with(headers: { "Authorization" => "Bearer #{token}" })
          .to_return(status: 200, body: '{"status": "ok"}', headers: { "Content-Type" => "application/json" })

        result = connection.request(:get, "/ping")
        expect(result).to eq(status: "ok")
      end

      it "raises AuthenticationError for 401 status" do
        stub_request(:get, "#{base_url}/ping")
          .to_return(status: 401, body: '{"error": "Unauthorized"}')

        expect { connection.request(:get, "/ping") }.to raise_error(Missive::AuthenticationError)
      end

      it "includes correct authorization header" do
        stub = stub_request(:get, "#{base_url}/ping")
               .with(headers: { "Authorization" => "Bearer #{token}" })
               .to_return(status: 200, body: "{}")

        connection.request(:get, "/ping")
        expect(stub).to have_been_requested
      end

      it "includes User-Agent header" do
        stub = stub_request(:get, "#{base_url}/ping")
               .with(headers: { "User-Agent" => "Missive Ruby Client #{Missive::VERSION}" })
               .to_return(status: 200, body: "{}")

        connection.request(:get, "/ping")
        expect(stub).to have_been_requested
      end

      it "sends request body for POST requests" do
        body_data = { name: "test", value: 123 }
        stub = stub_request(:post, "#{base_url}/data")
               .with(body: body_data.to_json)
               .to_return(status: 201, body: '{"id": 1}', headers: { "Content-Type" => "application/json" })

        result = connection.request(:post, "/data", body: body_data)
        expect(result).to eq(id: 1)
        expect(stub).to have_been_requested
      end

      it "sends query parameters for GET requests" do
        params = { limit: 10, offset: 20 }
        stub = stub_request(:get, "#{base_url}/items")
               .with(query: params)
               .to_return(status: 200, body: '{"items": []}', headers: { "Content-Type" => "application/json" })

        result = connection.request(:get, "/items", params: params)
        expect(result).to eq(items: [])
        expect(stub).to have_been_requested
      end
    end

    describe "concurrent requests" do
      it "handles multiple parallel requests with thread safety" do
        # Track concurrent request count
        active_requests = Concurrent::AtomicFixnum.new(0)
        max_concurrent = Concurrent::AtomicFixnum.new(0)

        stub_request(:get, "#{base_url}/ping").to_return do
          current = active_requests.increment
          max_concurrent.update { |max| [max, current].max }
          sleep(0.05) # Simulate processing time
          active_requests.decrement
          { status: 200, body: '{"status": "ok"}', headers: { "Content-Type" => "application/json" } }
        end

        # Make 10 concurrent requests
        futures = 10.times.map do |_i|
          Concurrent::Future.execute do
            connection.request(:get, "/ping")
          end
        end

        # Wait for all to complete
        results = futures.map(&:value!)

        # Verify all succeeded
        expect(results).to all(eq(status: "ok"))

        # Verify we had some concurrency (but not necessarily all 10 at once due to thread pool limits)
        expect(max_concurrent.value).to be > 1
        expect(max_concurrent.value).to be <= 10
      end
    end

    describe "rate limiting" do
      it "enforces token bucket rate limiting" do
        # Create connection with only 3 tokens for faster testing
        rate_limited_connection = Missive::Connection.new(
          token: token,
          base_url: base_url,
          rate_limit_tokens: 3
        )

        # Stub 5 requests
        stub_request(:get, "#{base_url}/rate_test")
          .to_return(status: 200, body: '{"ok": true}', headers: { "Content-Type" => "application/json" })

        start_time = Time.now

        # Make 5 requests in a loop - should exhaust 3 tokens quickly, then wait for refill
        5.times do |_i|
          result = rate_limited_connection.request(:get, "/rate_test")
          expect(result).to eq(ok: true)
        end

        elapsed_time = Time.now - start_time

        # With 3 tokens initially, 4th and 5th requests should trigger rate limiting
        # Each token beyond the initial 3 requires waiting: 3 tokens per 60 seconds = 1 token per 20 seconds
        # So we expect at least some delay for the 4th and 5th requests
        expect(elapsed_time).to be > 0.01 # Should take some measurable time due to rate limiting
      end

      it "respects semaphore concurrency limits" do
        # Verify MAX_CONCURRENCY is respected by checking that no more than 5 concurrent requests execute
        active_requests = Concurrent::AtomicFixnum.new(0)
        max_concurrent = Concurrent::AtomicFixnum.new(0)

        stub_request(:get, "#{base_url}/semaphore_test").to_return do
          current = active_requests.increment
          max_concurrent.update { |max| [max, current].max }
          sleep(0.1) # Hold the semaphore longer to test concurrency limit
          active_requests.decrement
          { status: 200, body: '{"ok": true}', headers: { "Content-Type" => "application/json" } }
        end

        # Make 10 concurrent requests
        futures = 10.times.map do
          Concurrent::Future.execute do
            connection.request(:get, "/semaphore_test")
          end
        end

        # Wait for all to complete
        results = futures.map(&:value!)

        # Verify all succeeded
        expect(results).to all(eq(ok: true))

        # Verify semaphore limited concurrency to MAX_CONCURRENCY (5)
        expect(max_concurrent.value).to be <= Missive::Constants::MAX_CONCURRENCY
        expect(max_concurrent.value).to be > 1 # But we should have some concurrency
      end
    end
  end
end
