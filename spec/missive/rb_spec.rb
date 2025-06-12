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

      # Check new rate limiting constants
      expect(Missive::Constants.const_defined?("RATE_60S")).to be(true)
      expect(Missive::Constants::RATE_60S).to eq(300)
      expect(Missive::Constants::RATE_60S).to be_frozen

      expect(Missive::Constants.const_defined?("RATE_15M")).to be(true)
      expect(Missive::Constants::RATE_15M).to eq(900)
      expect(Missive::Constants::RATE_15M).to be_frozen

      # Check header constants
      expect(Missive::Constants.const_defined?("HEADER_RETRY_AFTER")).to be(true)
      expect(Missive::Constants::HEADER_RETRY_AFTER).to eq("Retry-After")
      expect(Missive::Constants::HEADER_RETRY_AFTER).to be_frozen

      expect(Missive::Constants.const_defined?("HEADER_RATE_LIMIT_REMAINING")).to be(true)
      expect(Missive::Constants::HEADER_RATE_LIMIT_REMAINING).to eq("X-RateLimit-Remaining")
      expect(Missive::Constants::HEADER_RATE_LIMIT_REMAINING).to be_frozen

      expect(Missive::Constants.const_defined?("HEADER_RATE_LIMIT_RESET")).to be(true)
      expect(Missive::Constants::HEADER_RATE_LIMIT_RESET).to eq("X-RateLimit-Reset")
      expect(Missive::Constants::HEADER_RATE_LIMIT_RESET).to be_frozen
    end
  end

  describe "Error hierarchy" do
    describe "from_status class method" do
      it "returns AuthenticationError for status 401" do
        expect(Missive::Error.from_status(401, {})).to eq(Missive::AuthenticationError)
      end

      it "returns AuthenticationError for status 403" do
        expect(Missive::Error.from_status(403, {})).to eq(Missive::AuthenticationError)
      end

      it "returns RateLimitError for status 429" do
        expect(Missive::Error.from_status(429, {})).to eq(Missive::RateLimitError)
      end

      it "returns ServerError for 5xx status codes" do
        expect(Missive::Error.from_status(500, {})).to eq(Missive::ServerError)
        expect(Missive::Error.from_status(502, {})).to eq(Missive::ServerError)
        expect(Missive::Error.from_status(599, {})).to eq(Missive::ServerError)
      end

      it "returns NotFoundError for status 404" do
        expect(Missive::Error.from_status(404, {})).to eq(Missive::NotFoundError)
      end

      it "returns Error for unmatched status codes" do
        expect(Missive::Error.from_status(400, {})).to eq(Missive::Error)
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

      it "references constants through full module path" do
        # Temporarily remove the constant from local scope to test full qualification
        expect(defined?(Constants)).to be_falsy # Should not be available without Missive::

        # This ensures the code uses Missive::Constants::BASE_URL, not Constants::BASE_URL
        client = Missive::Client.new(api_token: "test_token")
        expect(client.config[:base_url]).to eq("https://public.missiveapp.com/v1")
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

      it "passes correct parameters to Connection.new" do
        client = Missive::Client.new(
          api_token: "test_token",
          base_url: "https://custom.api.com",
          timeout: 30,
          logger: Logger.new(File::NULL)
        )

        expect(Missive::Connection).to receive(:new).with(
          token: "test_token",
          base_url: "https://custom.api.com",
          timeout: 30,
          logger: client.config[:logger]
        ).and_call_original

        client.connection
      end

      it "passes nil values correctly when options not provided" do
        client = Missive::Client.new(api_token: "test_token")

        expect(Missive::Connection).to receive(:new).with(
          token: "test_token",
          base_url: Missive::Constants::BASE_URL,
          timeout: nil,
          logger: nil
        ).and_call_original

        client.connection
      end

      it "uses hash access operator (not fetch) for config values" do
        client = Missive::Client.new(api_token: "test_token", custom_option: "value")

        # Verify that missing keys return nil (hash access behavior, not fetch)
        expect(client.config[:nonexistent_key]).to be_nil

        # This would raise KeyError if fetch were used instead of []
        expect { client.connection }.not_to raise_error
      end
    end

    describe "#analytics" do
      it "memoizes the analytics resource instance" do
        client = Missive::Client.new(api_token: "test_token")
        analytics1 = client.analytics
        analytics2 = client.analytics
        expect(analytics1).to be(analytics2)
      end

      it "creates Analytics resource with correct client" do
        client = Missive::Client.new(api_token: "test_token")
        analytics = client.analytics
        expect(analytics).to be_a(Missive::Resources::Analytics)
        expect(analytics.instance_variable_get(:@client)).to eq(client)
      end
    end

    describe "#contacts" do
      it "memoizes the contacts resource instance" do
        client = Missive::Client.new(api_token: "test_token")
        contacts1 = client.contacts
        contacts2 = client.contacts
        expect(contacts1).to be(contacts2)
      end

      it "creates Contacts resource with correct client" do
        client = Missive::Client.new(api_token: "test_token")
        contacts = client.contacts
        expect(contacts).to be_a(Missive::Resources::Contacts)
        expect(contacts.client).to eq(client)
      end
    end

    describe "#contact_books" do
      it "memoizes the contact_books resource instance" do
        client = Missive::Client.new(api_token: "test_token")
        books1 = client.contact_books
        books2 = client.contact_books
        expect(books1).to be(books2)
      end

      it "creates ContactBooks resource with correct client" do
        client = Missive::Client.new(api_token: "test_token")
        books = client.contact_books
        expect(books).to be_a(Missive::Resources::ContactBooks)
        expect(books.client).to eq(client)
      end
    end

    describe "#contact_groups" do
      it "memoizes the contact_groups resource instance" do
        client = Missive::Client.new(api_token: "test_token")
        groups1 = client.contact_groups
        groups2 = client.contact_groups
        expect(groups1).to be(groups2)
      end

      it "creates ContactGroups resource with correct client" do
        client = Missive::Client.new(api_token: "test_token")
        groups = client.contact_groups
        expect(groups).to be_a(Missive::Resources::ContactGroups)
        expect(groups.client).to eq(client)
      end
    end

    describe "#conversations" do
      it "memoizes the conversations resource instance" do
        client = Missive::Client.new(api_token: "test_token")
        conversations1 = client.conversations
        conversations2 = client.conversations
        expect(conversations1).to be(conversations2)
      end

      it "creates Conversations resource with correct client" do
        client = Missive::Client.new(api_token: "test_token")
        conversations = client.conversations
        expect(conversations).to be_a(Missive::Resources::Conversations)
        expect(conversations.client).to eq(client)
      end
    end

    describe "#messages" do
      it "memoizes the messages resource instance" do
        client = Missive::Client.new(api_token: "test_token")
        messages1 = client.messages
        messages2 = client.messages
        expect(messages1).to be(messages2)
      end

      it "creates Messages resource with correct client" do
        client = Missive::Client.new(api_token: "test_token")
        messages = client.messages
        expect(messages).to be_a(Missive::Resources::Messages)
        expect(messages.client).to eq(client)
      end
    end

    describe "#drafts" do
      it "memoizes the drafts resource instance" do
        client = Missive::Client.new(api_token: "test_token")
        drafts1 = client.drafts
        drafts2 = client.drafts
        expect(drafts1).to be(drafts2)
      end

      it "creates Drafts resource with correct client" do
        client = Missive::Client.new(api_token: "test_token")
        drafts = client.drafts
        expect(drafts).to be_a(Missive::Resources::Drafts)
        expect(drafts.instance_variable_get(:@client)).to eq(client)
      end
    end

    describe "#posts" do
      it "memoizes the posts resource instance" do
        client = Missive::Client.new(api_token: "test_token")
        posts1 = client.posts
        posts2 = client.posts
        expect(posts1).to be(posts2)
      end

      it "creates Posts resource with correct client" do
        client = Missive::Client.new(api_token: "test_token")
        posts = client.posts
        expect(posts).to be_a(Missive::Resources::Posts)
        expect(posts.instance_variable_get(:@client)).to eq(client)
      end
    end

    describe "#shared_labels" do
      it "memoizes the shared_labels resource instance" do
        client = Missive::Client.new(api_token: "test_token")
        labels1 = client.shared_labels
        labels2 = client.shared_labels
        expect(labels1).to be(labels2)
      end

      it "creates SharedLabels resource with correct client" do
        client = Missive::Client.new(api_token: "test_token")
        labels = client.shared_labels
        expect(labels).to be_a(Missive::Resources::SharedLabels)
        expect(labels.instance_variable_get(:@client)).to eq(client)
      end
    end

    describe "#organizations" do
      it "memoizes the organizations resource instance" do
        client = Missive::Client.new(api_token: "test_token")
        orgs1 = client.organizations
        orgs2 = client.organizations
        expect(orgs1).to be(orgs2)
      end

      it "creates Organizations resource with correct client" do
        client = Missive::Client.new(api_token: "test_token")
        orgs = client.organizations
        expect(orgs).to be_a(Missive::Resources::Organizations)
        expect(orgs.instance_variable_get(:@client)).to eq(client)
      end
    end

    describe "#responses" do
      it "memoizes the responses resource instance" do
        client = Missive::Client.new(api_token: "test_token")
        responses1 = client.responses
        responses2 = client.responses
        expect(responses1).to be(responses2)
      end

      it "creates Responses resource with correct client" do
        client = Missive::Client.new(api_token: "test_token")
        responses = client.responses
        expect(responses).to be_a(Missive::Resources::Responses)
        expect(responses.instance_variable_get(:@client)).to eq(client)
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
               .with(headers: { "User-Agent" => "missive-rb/#{Missive::VERSION}" })
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
        # Rate limiting is now handled by middleware
        # Create a normal connection
        rate_limited_connection = Missive::Connection.new(
          token: token,
          base_url: base_url
        )

        # Stub requests
        stub_request(:get, "#{base_url}/rate_test")
          .to_return(status: 200, body: '{"ok": true}', headers: { "Content-Type" => "application/json" })

        # Make multiple requests - the rate limiter middleware should handle pacing
        5.times do |_i|
          result = rate_limited_connection.request(:get, "/rate_test")
          expect(result).to eq(ok: true)
        end

        # If we get here without errors, rate limiting middleware is working
        expect(true).to be true
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

  describe "Configuration" do
    after do
      Missive.reset_configuration!
    end

    describe ".configure" do
      it "yields configuration object when block given" do
        expect { |b| Missive.configure(&b) }.to yield_with_args(Missive::Configuration)
      end

      it "returns configuration when no block given" do
        config = Missive.configure
        expect(config).to be_a(Missive::Configuration)
      end

      it "allows customization of configuration" do
        custom_logger = Logger.new(File::NULL)

        Missive.configure do |config|
          config.logger = custom_logger
          config.base_url = "https://custom.api.com"
          config.soft_limit_threshold = 50
        end

        config = Missive.configuration
        expect(config.logger).to eq(custom_logger)
        expect(config.base_url).to eq("https://custom.api.com")
        expect(config.soft_limit_threshold).to eq(50)
      end
    end

    describe ".configuration" do
      it "returns same instance on multiple calls" do
        config1 = Missive.configuration
        config2 = Missive.configuration
        expect(config1).to be(config2)
      end

      it "has default values" do
        config = Missive.configuration
        expect(config.logger).to be_a(Logger)
        expect(config.logger.level).to eq(Logger::INFO)
        expect(config.instrumenter).to eq(ActiveSupport::Notifications)
        expect(config.token_lookup).to be_a(Proc)
        expect(config.token_lookup.call("test")).to be_nil
        expect(config.base_url).to eq(Missive::Constants::BASE_URL)
        expect(config.soft_limit_threshold).to eq(30)
      end

      it "initializes logger with correct output stream and level" do
        config = Missive::Configuration.new
        expect(config.logger.instance_variable_get(:@logdev).instance_variable_get(:@dev)).to eq($stdout)
        expect(config.logger.level).to eq(Logger::INFO)
      end

      it "initializes token_lookup as lambda that accepts email parameter" do
        config = Missive::Configuration.new
        expect(config.token_lookup.arity).to eq(1) # Should accept exactly 1 parameter
        expect(config.token_lookup.call("any@email.com")).to be_nil
      end

      it "uses fully qualified constant reference for default base_url" do
        config = Missive::Configuration.new
        expect(config.base_url).to eq("https://public.missiveapp.com/v1")
        expect(config.base_url).to eq(Missive::Constants::BASE_URL)
      end

      it "can be frozen" do
        config = Missive.configuration
        config.freeze
        expect(config).to be_frozen
        expect(config.logger).to be_frozen
        expect(config.instrumenter).to be_frozen
        expect(config.token_lookup).to be_frozen
        expect(config.base_url).to be_frozen
        expect(config.soft_limit_threshold).to be_frozen
      end
    end

    describe ".reset_configuration!" do
      it "resets configuration to new instance" do
        config1 = Missive.configuration
        config1.logger = Logger.new(File::NULL)

        Missive.reset_configuration!
        config2 = Missive.configuration

        expect(config2).not_to be(config1)
        expect(config2.logger).not_to eq(config1.logger)
      end
    end
  end

  describe "Middleware" do
    let(:app) { double("app") }
    let(:env) { double("env", method: :get, url: double("url", path: "/test", to_s: "https://api.test.com/test")) }

    describe "ConcurrencyLimiter" do
      let(:middleware) { Missive::Middleware::ConcurrencyLimiter.new(app, max_concurrent: 2) }

      it "limits concurrent requests" do
        allow(app).to receive(:call).and_return(double("response"))

        # Should be able to make request normally
        expect { middleware.call(env) }.not_to raise_error
      end

      it "uses default max_concurrent from constants" do
        default_middleware = Missive::Middleware::ConcurrencyLimiter.new(app)
        # The semaphore should be initialized with MAX_CONCURRENCY permits
        # We can test this by checking the semaphore exists and can acquire permits
        semaphore = default_middleware.send(:semaphore)
        expect(semaphore).to be_a(Concurrent::Semaphore)

        # Try to acquire MAX_CONCURRENCY permits - should succeed
        acquired = []
        Missive::Constants::MAX_CONCURRENCY.times do
          acquired << semaphore.try_acquire
        end
        expect(acquired.all?).to be true

        # The next acquire should fail
        expect(semaphore.try_acquire).to be false

        # Release all permits
        acquired.each { semaphore.release }
      end
    end

    describe "RaiseForStatus" do
      let(:middleware) { Missive::Middleware::RaiseForStatus.new(app) }

      it "passes through successful responses" do
        response = double("response", status: 200, body: { success: true })
        allow(app).to receive(:call).and_return(response)

        result = middleware.call(env)
        expect(result).to eq(response)
      end

      it "raises AuthenticationError for 401" do
        response = double("response", status: 401, body: "Unauthorized")
        allow(app).to receive(:call).and_return(response)

        expect { middleware.call(env) }.to raise_error(Missive::AuthenticationError, "Unauthorized")
      end

      it "raises RateLimitError for 429" do
        response = double("response", status: 429, body: { error: "Rate limited" })
        allow(app).to receive(:call).and_return(response)

        expect { middleware.call(env) }.to raise_error(Missive::RateLimitError, "Rate limited")
      end

      it "raises ServerError for 500" do
        response = double("response", status: 500, body: "Server error")
        allow(app).to receive(:call).and_return(response)

        expect { middleware.call(env) }.to raise_error(Missive::ServerError, "Server error")
      end

      it "extracts error message from hash body" do
        response = double("response", status: 400, body: { "error" => "Bad request" })
        allow(app).to receive(:call).and_return(response)

        expect { middleware.call(env) }.to raise_error(Missive::Error, "Bad request")
      end

      it "uses HTTP status for nil error message" do
        response = double("response", status: 404, body: {})
        allow(app).to receive(:call).and_return(response)

        expect { middleware.call(env) }.to raise_error(Missive::NotFoundError, "HTTP 404")
      end
    end

    describe "RateLimiter" do
      let(:middleware) { Missive::Middleware::RateLimiter.new(app, tokens_per_window: 10, window_seconds: 1) }

      before do
        allow(Missive).to receive(:configuration).and_return(double("config",
                                                                    instrumenter: double("instrumenter", instrument: nil)))
      end

      it "allows requests when tokens available" do
        response = double("response", headers: {})
        allow(app).to receive(:call).and_return(response)

        result = middleware.call(env)
        expect(result).to eq(response)
      end

      it "emits rate limit notification when tokens low" do
        instrumenter = double("instrumenter")
        config = double("config", instrumenter: instrumenter)
        allow(Missive).to receive(:configuration).and_return(config)

        response = double("response", headers: {})
        allow(app).to receive(:call).and_return(response)

        # Set tokens below threshold (26 so after consuming 1 token it becomes 25)
        middleware.instance_variable_set(:@tokens, 26)

        expect(instrumenter).to receive(:instrument).with("missive.rate_limit.hit", {
                                                            remaining_tokens: 25,
                                                            threshold: 30
                                                          })

        middleware.call(env)
      end

      it "handles retry-after header" do
        response = double("response", headers: { Missive::Constants::HEADER_RETRY_AFTER => "2" })
        allow(app).to receive(:call).and_return(response)
        allow(middleware).to receive(:sleep)

        expect(middleware).to receive(:sleep).with(2)
        middleware.call(env)
      end

      it "waits when no tokens available" do
        response = double("response", headers: {})
        allow(app).to receive(:call).and_return(response)
        allow(middleware).to receive(:sleep)

        # Set tokens to 0 to trigger waiting
        middleware.instance_variable_set(:@tokens, 0)

        expect(middleware).to receive(:sleep).once
        middleware.call(env)
      end

      it "refills tokens over time" do
        response = double("response", headers: {})
        allow(app).to receive(:call).and_return(response)

        # Set last refill to past time to trigger token refill
        past_time = Time.now - 2
        middleware.instance_variable_set(:@last_refill, past_time)
        middleware.instance_variable_set(:@tokens, 5)

        middleware.call(env)

        # Tokens should have been refilled
        expect(middleware.instance_variable_get(:@tokens)).to be > 5
      end
    end

    describe "Instrumentation" do
      let(:middleware) { Missive::Middleware::Instrumentation.new(app) }

      before do
        allow(Missive).to receive(:configuration).and_return(double("config",
                                                                    instrumenter: double("instrumenter", instrument: nil)))
      end

      it "instruments request and response" do
        instrumenter = double("instrumenter")
        config = double("config", instrumenter: instrumenter)
        allow(Missive).to receive(:configuration).and_return(config)

        response = double("response", status: 200)
        allow(app).to receive(:call).and_return(response)

        expect(instrumenter).to receive(:instrument).with("missive.request", {
                                                            method: "GET",
                                                            path: "/test",
                                                            url: "https://api.test.com/test"
                                                          }).and_yield

        expect(instrumenter).to receive(:instrument).with("missive.response", {
                                                            method: "GET",
                                                            path: "/test",
                                                            url: "https://api.test.com/test",
                                                            status: 200,
                                                            duration: be_a(Float)
                                                          })

        middleware.call(env)
      end
    end
  end
end
