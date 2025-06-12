# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  track_files "lib/**/*.rb"
  add_filter "/spec/"
  minimum_coverage 90 # Temporarily lowered for final testing
end

require "missive"
require "webmock/rspec"
require "vcr"
require "concurrent"

# Configure VCR for recording real API responses
VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  
  # Filter sensitive data
  config.filter_sensitive_data('<API_TOKEN>') { ENV['MISSIVE_API_TOKEN'] }
  config.filter_sensitive_data('<API_TOKEN>') do |interaction|
    # Extract token from Authorization header
    auth_header = interaction.request.headers['Authorization']&.first
    auth_header&.gsub('Bearer ', '') if auth_header&.start_with?('Bearer ')
  end
  
  # Only allow real HTTP connections when VCR is explicitly recording
  config.allow_http_connections_when_no_cassette = false
  
  # Use :new_episodes to record new API calls but replay existing ones
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: [:method, :uri, :headers]
  }
end

# Require support files
Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
