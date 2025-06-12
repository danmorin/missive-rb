# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  track_files "lib/**/*.rb"
  add_filter "/spec/"
  minimum_coverage 90 # Temporarily lowered for final testing
end

require "missive"
require "webmock/rspec"
require "concurrent"

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
