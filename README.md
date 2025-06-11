# Missive Ruby Client

A Ruby client library for the Missive API, providing thread-safe connection management, rate limiting, and comprehensive error handling.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'missive-rb'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install missive-rb
```

## Usage

Here's a minimal example to get started:

```ruby
require 'missive'

# Initialize the client with your API token
client = Missive::Client.new(api_token: 'your_api_token_here')

# Make a simple ping request
response = client.connection.request(:get, '/ping')
puts response # => { status: "ok" }
```

### Analytics Quick Start

The Analytics resource allows you to create and manage analytics reports:

```ruby
# Create an analytics report with Unix timestamps
report = client.analytics.create_report(
  organization: '0d9bab85-a74f-4ece-9142-0f9b9f36ff92',
  start_time: 1691812800,  # Unix timestamp for report period start
  end_time: 1692371867,    # Unix timestamp for report period end
  time_zone: 'America/Montreal'
)

# Wait for the report to complete processing
completed_report = client.analytics.wait_for_report(
  report_id: report.id,
  interval: 5,    # Check every 5 seconds
  timeout: 120    # Timeout after 2 minutes
)

# Access the analytics data directly
puts "Report start: #{completed_report.start}"
puts "Report end: #{completed_report.end}"
puts "Metrics: #{completed_report.selected_period.global.totals.metrics}" if completed_report.selected_period
```

You can also manually fetch a completed report:

```ruby
# Get completed report data (returns 404 if not ready)
report = client.analytics.get_report(report_id: 'abc123')
puts "Report start: #{report.start}"
puts "Report end: #{report.end}"
```

### Pagination

For API endpoints that return paginated results, you can use the `Missive::Paginator` module:

```ruby
# Iterate through all pages
Missive::Paginator.each_page(path: '/conversations', client: client) do |page|
  puts "Processing page with #{page['data'].length} items"
end

# Iterate through individual items across all pages
Missive::Paginator.each_item(path: '/conversations', client: client) do |conversation|
  puts "Conversation: #{conversation['subject']}"
end

# Limit the number of pages or items
Missive::Paginator.each_page(
  path: '/conversations',
  client: client,
  max_pages: 3,
  sleep_interval: 1  # Sleep 1 second between pages
) do |page|
  # Process page
end

Missive::Paginator.each_item(
  path: '/conversations',
  client: client,
  max_items: 100
) do |conversation|
  # Process conversation
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/danmorin/missive-rb. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/danmorin/missive-rb/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Missive::Rb project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/danmorin/missive-rb/blob/main/CODE_OF_CONDUCT.md).
