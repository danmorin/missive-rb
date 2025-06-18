# Missive Ruby Client

> **⚠️ Disclaimer:** This library was built with Claude Code and has not been fully tested by humans in production environments. Please log any issues you find. Pull requests are appreciated!

[![Gem Version](https://badge.fury.io/rb/missive-rb.svg)](https://badge.fury.io/rb/missive-rb)
[![CI](https://github.com/danmorin/missive-rb/workflows/CI/badge.svg)](https://github.com/danmorin/missive-rb/actions)
[![Coverage](https://codecov.io/gh/danmorin/missive-rb/branch/main/graph/badge.svg)](https://codecov.io/gh/danmorin/missive-rb)

A Ruby client library for the Missive API, providing thread-safe connection management, rate limiting, and comprehensive error handling.

## Why missive-rb?

**missive-rb** stands out as the most comprehensive and production-ready Ruby client for the Missive API:

- **🚀 Complete API Coverage** - Full support for all 15 Missive API resources
- **⚡ Performance Optimized** - Built-in rate limiting, connection pooling, and optional caching
- **🔒 Enterprise Ready** - Thread-safe design, comprehensive error handling, and webhook validation
- **🛠️ Developer Friendly** - Rich CLI tools, extensive documentation, and Rails integration
- **📊 Monitoring Built-in** - ActiveSupport::Notifications integration for observability

## Quick Start

```bash
gem install missive-rb
```

## Resource Coverage

| Resource | Create | Read | Update | Delete | List | Paginate |
|----------|--------|------|--------|--------|------|----------|
| **Analytics** | ✅ | ✅ | ➖ | ➖ | ➖ | ➖ |
| **Contacts** | ✅ | ✅ | ✅ | ➖ | ✅ | ✅ |
| **Contact Books** | ➖ | ➖ | ➖ | ➖ | ✅ | ✅ |
| **Contact Groups** | ➖ | ➖ | ➖ | ➖ | ✅ | ✅ |
| **Conversations** | ➖ | ✅ | ➖ | ➖ | ✅ | ✅ |
| **Messages** | ✅ | ✅ | ➖ | ➖ | ✅ | ✅ |
| **Drafts** | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ |
| **Posts** | ✅ | ➖ | ➖ | ✅ | ➖ | ➖ |
| **SharedLabels** | ✅ | ➖ | ✅ | ➖ | ✅ | ✅ |
| **Organizations** | ➖ | ➖ | ➖ | ➖ | ✅ | ✅ |
| **Responses** | ➖ | ✅ | ➖ | ➖ | ✅ | ✅ |
| **Tasks** | ✅ | ➖ | ✅ | ➖ | ➖ | ➖ |
| **Teams** | ➖ | ➖ | ➖ | ➖ | ✅ | ✅ |
| **Users** | ➖ | ➖ | ➖ | ➖ | ✅ | ✅ |
| **Hooks** | ✅ | ➖ | ➖ | ✅ | ➖ | ➖ |

## Installation

```bash
gem install missive-rb
```

## Usage

Here's a minimal example to get started:

```ruby
require 'missive'

# Initialize the client with your API token
client = Missive::Client.new(api_token: 'your_api_token_here')

# List organizations to verify API connection
organizations = client.organizations.list(limit: 1)
puts organizations.first.name if organizations.any?
```

### Analytics Quick Start

The Analytics resource allows you to create and manage analytics reports:

```ruby
# Create an analytics report with Unix timestamps
report = client.analytics.create_report(
  organization: 'your-organization-id-here',
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
# Access nested data using dig() method or hash syntax
metrics = completed_report.dig(:selected_period, :global, :totals, :metrics)
puts "Metrics: #{metrics}" if metrics
```

You can also manually fetch a completed report:

```ruby
# Get completed report data (returns 404 if not ready)
report = client.analytics.get_report(report_id: 'your-report-id-here')
puts "Report start: #{report.start}"
puts "Report end: #{report.end}"
```

### Contact Books

List available contact books:

```ruby
# List contact books
books = client.contact_books.list(limit: 50)

# Iterate through all contact books
client.contact_books.each_item do |book|
  puts "Book: #{book.name} (#{book.id})"
end
```

### Contacts Management

The Contacts API allows you to create, update, list, and retrieve contacts:

```ruby
# List contacts from a contact book
contacts = client.contacts.list(
  contact_book: "book-id-here",
  limit: 10
)

# Create a new contact
new_contact = client.contacts.create(
  contacts: {
    email: "john@example.com",
    first_name: "John",
    last_name: "Doe",
    contact_book: "book-id-here"
  }
)

# Update existing contacts
updated = client.contacts.update(
  contact_hashes: [
    { id: "your-contact-id-1", first_name: "Jane" },
    { id: "your-contact-id-2", last_name: "Smith" }
  ]
)

# Get a specific contact
contact = client.contacts.get(id: "your-contact-id-here")
puts "#{contact.first_name} #{contact.last_name}"

# Iterate through all contacts with pagination
client.contacts.each_item(contact_book: "book-id-here") do |contact|
  puts "#{contact.first_name} #{contact.last_name}"
end
```

### Contact Groups

Manage groups and organizations within contact books:

```ruby
# List groups in a contact book
groups = client.contact_groups.list(
  contact_book: "book-id-here",
  kind: "group"  # or "organization"
)

# Iterate through all groups
client.contact_groups.each_item(
  contact_book: "book-id-here",
  kind: "group"
) do |group|
  puts "Group: #{group.name}"
end
```

### Working with Conversations

The Conversations API allows you to list conversations, retrieve individual conversations, and access their messages and comments:

```ruby
# List conversations in your inbox
conversations = client.conversations.list(inbox: true, limit: 25)
conversations.each do |conv|
  puts "#{conv.subject} - #{conv.latest_message_subject}"
end

# Get a specific conversation
conversation = client.conversations.get(id: "your-conversation-id-here")
puts "Subject: #{conversation.subject}"
puts "Messages count: #{conversation.messages_count}"

# Fetch messages within a conversation
messages = client.conversations.messages(
  conversation_id: "your-conversation-id-here",
  limit: 10  # Max 10 per request
)

messages.each do |message|
  puts "From: #{message.from_field&.name} <#{message.from_field&.address}>"
  puts "Subject: #{message.subject}"
  puts "Body preview: #{message.preview || message.body&.truncate(100)}"
  puts "---"
end

# Fetch comments on a conversation
comments = client.conversations.comments(
  conversation_id: "your-conversation-id-here",
  limit: 10
)

comments.each do |comment|
  puts "Comment by #{comment.author&.name}: #{comment.body&.truncate(100)}"
end

# Iterate through all conversations with automatic pagination
client.conversations.each_item(inbox: true) do |conversation|
  puts "Processing: #{conversation.subject}"
  # Break after processing 100 conversations
  break if processed_count >= 100
end

# Paginate through all messages in a conversation
client.conversations.each_message(conversation_id: "your-conversation-id-here") do |message|
  # Process each message
  puts "Message #{message.id}: #{message.subject}"
end
```

### Working with Messages

The Messages API allows you to retrieve individual messages, search by email message ID, and create messages for custom channels:

```ruby
# Get a specific message by ID
message = client.messages.get(id: "your-message-id-here")
puts "Subject: #{message.subject}"
puts "From: #{message.from_field.name} <#{message.from_field.address}>"
puts "To: #{message.to_fields.map { |f| "#{f.name} <#{f.address}>" }.join(", ")}"

# Access message attachments
message.attachments&.each do |attachment|
  puts "Attachment: #{attachment.filename} (#{attachment.size} bytes)"
  puts "URL: #{attachment.url}"
end

# Search for messages by email message ID
email_id = "<466FC415-3B23-4B54-ADA5-F6A598329D7F@duoyeah.com>"
messages = client.messages.list_by_email_message_id(email_message_id: email_id)

messages.each do |msg|
  puts "Found message: #{msg.subject} (#{msg.id})"
end

# Create a message for a custom channel (for integrations)
custom_message = client.messages.create_for_custom_channel(
  channel_id: "your-channel-id-here",
  from_field: { 
    id: "bot-123", 
    username: "@supportbot",
    name: "Support Bot"
  },
  to_fields: [{ 
    id: "user-456", 
    username: "@customer",
    name: "John Doe"
  }],
  body: "Hello! This is an automated message from your support system.",
  subject: "Support Ticket #12345",
  attachments: [] # Optional
)

puts "Created message: #{custom_message.id}"
```

### Creating and Sending Drafts

The Drafts API provides comprehensive support for email, SMS, WhatsApp, and custom channels with advanced features like scheduling, team management, and file attachments:

```ruby
# Create a basic email draft
draft = client.drafts.create(
  subject: "Welcome to our service",
  body: "Hello! Thank you for signing up.",
  to_fields: [{ address: "customer@example.com", name: "John Doe" }],
  from_field: { address: "support@company.com", name: "Support Team" }
)

puts "Draft created: #{draft.id}"

# Create draft with file attachments (max 25 files)
draft_with_files = client.drafts.create(
  subject: "Your requested documents",
  body: "Please find the attached documents.",
  to_fields: [{ address: "client@example.com" }],
  from_field: { address: "documents@company.com" },
  cc_fields: [{ address: "manager@company.com", name: "Manager" }],
  bcc_fields: [{ address: "archive@company.com" }],
  attachments: [
    {
      base64_data: "iVBORw0KGgoAAAANSUhEUgAA...", # Base64 encoded file
      filename: "contract.pdf"
    },
    {
      base64_data: "R0lGODlhAQABAIAAAAAAAP//...",
      filename: "logo.png"
    }
  ]
)

# Send immediately
sent_message = client.drafts.send_message(
  subject: "Urgent: System maintenance tonight",
  body: "Our systems will be down for maintenance tonight from 2-4 AM EST.",
  to_fields: [{ address: "all-users@company.com" }],
  from_field: { address: "alerts@company.com", name: "System Alerts" }
)

puts "Message sent: #{sent_message.id}"

# Schedule for later delivery
scheduled_draft = client.drafts.schedule_message(
  send_at: Time.now.to_i + 3600, # Send in 1 hour
  auto_followup: true, # Cancel if conversation receives reply
  subject: "Follow-up on your inquiry",
  body: "We wanted to follow up on your recent inquiry...",
  to_fields: [{ address: "prospect@example.com" }],
  from_field: { address: "sales@company.com" }
)

puts "Message scheduled: #{scheduled_draft.id}"

# Create draft for existing conversation with team assignment
conversation_draft = client.drafts.create(
  body: "This issue has been escalated to our engineering team.",
  to_fields: [{ address: "customer@example.com" }],
  from_field: { address: "support@company.com" },
  conversation: "existing-conversation-id",
  team: "engineering-team-id",
  organization: "company-org-id",
  add_assignees: ["engineer-user-id"],
  conversation_color: "warning",
  add_shared_labels: ["escalated-label-id"]
)

# WhatsApp template message
whatsapp_draft = client.drafts.create(
  body: "Hello {{1}}, your order {{2}} is ready for pickup!",
  to_fields: [{ phone_number: "+1234567890" }],
  from_field: { phone_number: "+1987654321", type: "whatsapp" },
  external_response_id: "474808552386201", # WhatsApp template ID
  external_response_variables: { "1" => "John", "2" => "#12345" }
)

# SMS message
sms_draft = client.drafts.create(
  body: "Your verification code is: 123456",
  to_fields: [{ phone_number: "+1234567890" }],
  from_field: { phone_number: "+1987654321", type: "twilio" }
)

# Custom channel message (for integrations)
custom_draft = client.drafts.create(
  body: "New support ticket created",
  to_fields: [{ id: "user-123", username: "@johndoe", name: "John Doe" }],
  from_field: { id: "bot-456", username: "@supportbot", name: "Support Bot" },
  account: "custom-channel-account-id"
)
```

### Injecting webhook posts

The Posts API allows you to inject posts into conversations for webhook integrations:

```ruby
# Create a webhook post with markdown content
post = client.posts.create(
  text: nil,  # Use markdown instead
  markdown: "## Alert: Server Issue\n\n**Server:** web-01\n**Status:** High CPU usage detected\n**Time:** #{Time.now}",
  conversation: "your-conversation-id-here",
  notification: {
    title: "Server Alert",
    body: "High CPU usage detected on web-01"
  }
)

puts "Webhook post created: #{post.id}"

# Create a post with attachments (e.g., graphs, logs)
attachment_post = client.posts.create(
  text: "System monitoring report attached",
  attachments: [
    {
      name: "cpu_graph.png",
      url: "https://monitoring.example.com/graphs/cpu_usage.png"
    },
    {
      name: "error_log.txt",
      url: "https://logs.example.com/errors/latest.txt"
    }
  ],
  conversation: "your-conversation-id-here"
)

# Delete a post if needed (e.g., false alarm)
client.posts.delete(id: "your-post-id-here")
puts "Post deleted"
```

### Advanced Examples

#### Processing Unread Conversations

```ruby
# Get all unread conversations and mark them as processed
unread_conversations = client.conversations.list(
  inbox: true,
  unread: true,  # Assuming this filter exists in the API
  limit: 50
)

unread_conversations.each do |conversation|
  # Get the latest messages
  messages = client.conversations.messages(
    conversation_id: conversation.id,
    limit: 5
  )
  
  # Process based on content
  latest_message = messages.first
  if latest_message&.body&.include?("urgent")
    puts "⚠️  URGENT: #{conversation.subject}"
    # Handle urgent messages
  end
end
```

#### Building a Message Thread View

```ruby
# Reconstruct a conversation thread
conversation_id = "your-conversation-id-here"

# Get conversation details
conv = client.conversations.get(id: conversation_id)
puts "=== #{conv.subject || conv.latest_message_subject} ==="
puts "Participants: #{conv.authors.map { |a| a.name }.join(", ")}"
puts ""

# Get all messages in chronological order
all_messages = []
client.conversations.each_message(conversation_id: conversation_id) do |message|
  all_messages << message
end

# Display thread
all_messages.reverse.each do |msg|
  puts "From: #{msg.from_field&.name} (#{msg.created_at})"
  puts "Subject: #{msg.subject}" if msg.subject
  puts msg.body&.truncate(200)
  puts "-" * 80
end

# Show comments separately
puts "\n=== Comments ==="
client.conversations.each_comment(conversation_id: conversation_id) do |comment|
  puts "#{comment.author&.name}: #{comment.body}"
end
```

#### Export Conversation Data

```ruby
# Export conversation data for analysis
require 'csv'

CSV.open("conversations_export.csv", "wb") do |csv|
  csv << ["ID", "Subject", "Created At", "Message Count", "Authors", "Status"]
  
  client.conversations.each_item(inbox: true) do |conv|
    csv << [
      conv.id,
      conv.subject || conv.latest_message_subject,
      conv.created_at,
      conv.messages_count,
      conv.authors.map { |a| a.name }.join("; "),
      conv.closed_at ? "Closed" : "Open"
    ]
  end
end

puts "Export completed!"
```

### Pagination

The Paginator class provides low-level pagination support. **Note:** Most resources have their own `each_item` methods that are easier to use and handle resource-specific requirements.

```ruby
# Use resource-specific pagination (recommended)
client.conversations.each_item(inbox: true, limit: 25) do |conversation|
  puts "Conversation: #{conversation.subject}"
end

# Low-level paginator (requires proper API parameters)
# Note: Conversations API requires at least one filter like inbox: true
Missive::Paginator.each_item(
  path: '/conversations', 
  client: client, 
  params: { inbox: true, limit: 25 }
) do |conversation|
  puts "Conversation: #{conversation[:subject]}"
end

# Iterate through all pages with low-level paginator
Missive::Paginator.each_page(
  path: '/conversations', 
  client: client, 
  params: { inbox: true, limit: 25 }
) do |page|
  puts "Processing page with #{page[:conversations].length} items"
end

# Limit items with resource methods (recommended)
processed = 0
client.conversations.each_item(inbox: true) do |conversation|
  puts "Processing: #{conversation.subject}"
  processed += 1
  break if processed >= 100
end

# Or use low-level paginator with limits
Missive::Paginator.each_item(
  path: '/conversations',
  client: client,
  params: { inbox: true },
  max_items: 100
) do |conversation|
  puts "Conversation: #{conversation[:subject]}"
end
```

### Concurrent Requests

The library is thread-safe and supports making multiple requests concurrently. The connection pool has built-in concurrency limiting (default: 5 concurrent requests) and thread-safe rate limiting.

```ruby
# Example 1: Fetch multiple conversations concurrently using threads
conversation_ids = ["conv1", "conv2", "conv3", "conv4", "conv5"]
conversations = []
threads = []

conversation_ids.each do |id|
  threads << Thread.new do
    conversations << client.conversations.get(id: id)
  end
end

threads.each(&:join)
puts "Fetched #{conversations.length} conversations concurrently"

# Example 2: Fetch different resource types in parallel
results = {}
threads = [
  Thread.new { results[:conversations] = client.conversations.list(limit: 10) },
  Thread.new { results[:contacts] = client.contacts.list(limit: 10) },
  Thread.new { results[:teams] = client.teams.list }
]

threads.each(&:join)
puts "Fetched #{results[:conversations].count} conversations, #{results[:contacts].count} contacts, #{results[:teams].count} teams"

# Example 3: Batch create contacts concurrently
contact_batches = [
  [{ email: "user1@example.com" }, { email: "user2@example.com" }],
  [{ email: "user3@example.com" }, { email: "user4@example.com" }]
]

threads = contact_batches.map do |batch|
  Thread.new { client.contacts.create(contacts: batch) }
end

results = threads.map(&:value)
total_created = results.sum { |r| r["contacts"].size }
puts "Created #{total_created} contacts concurrently"
```

## Managing tasks programmatically

The Tasks API allows you to create and update tasks programmatically:

```ruby
# Create a standalone task assigned to a team
task = client.tasks.create(
  title: "Follow up with client about proposal",
  team: "your-team-id-here",
  organization: "your-organization-id-here",
  description: "Review the proposal and schedule a follow-up meeting",
  due_at: (Time.now + 7.days).to_i
)

puts "Task created: #{task.id}"

# Create a subtask for a specific conversation
subtask = client.tasks.create(
  title: "Review attached documents",
  subtask: true,
  conversation: "your-conversation-id-here",
  state: "todo"
)

# Update task status and details
updated_task = client.tasks.update(
  id: "your-task-id-here",
  state: "done",
  title: "Updated: Follow up completed",
  description: "Meeting scheduled for next week"
)

puts "Task updated: #{updated_task.state}"
```

## Managing auto-responses

The Responses API allows you to list and retrieve auto-response templates:

```ruby
# List all auto-responses
responses = client.responses.list(limit: 50)
responses.each do |response|
  puts "Response: #{response.name}"
end

# List responses for a specific organization
org_responses = client.responses.list(
  organization: "your-organization-id-here",
  limit: 25
)

# Get a specific response by ID
response = client.responses.get(id: "your-response-id-here")
puts "Response name: #{response.name}"
puts "Response body: #{response.body}"

# Access attachments if present
response.attachments&.each do |attachment|
  puts "Attachment: #{attachment[:inline_image]}" if attachment[:inline_image]
end

# Iterate through all responses with pagination
client.responses.each_item(organization: "your-organization-id-here") do |response|
  puts "Processing response: #{response.name}"
end
```

## Registering webhooks securely

The Hooks API and WebhookServer middleware provide secure webhook management:

```ruby
# Create webhooks for different events
comment_hook = client.hooks.create(
  type: "new_comment",
  url: "https://your-app.com/webhooks/comments",
  organization: "your-organization-id-here"
)

email_hook = client.hooks.create(
  type: "incoming_email",
  url: "https://your-app.com/webhooks/emails",
  mailbox: "your-mailbox-id-here"
)

# Delete a webhook when no longer needed
client.hooks.delete(id: "your-hook-id-here")
```

### Setting up webhook validation

Use the WebhookServer middleware to validate webhook signatures:

```ruby
# In a Sinatra app
require 'sinatra'
require 'missive'

use Missive::WebhookServer, signature_secret: ENV['MISSIVE_WEBHOOK_SECRET']

post '/webhooks' do
  webhook_data = request.env['missive.webhook']
  
  if webhook_data
    puts "Received webhook: #{webhook_data[:type]}"
    # Process the webhook data
  end
  
  { status: 'ok' }.to_json
end

# Or use the mount helper for quick setup
app = Missive::WebhookServer.mount('/webhooks', ENV['MISSIVE_WEBHOOK_SECRET'])
run app
```

### Rails integration

In Rails, add webhook validation to your routes:

```ruby
# config/application.rb
config.middleware.use Missive::WebhookServer, 
  signature_secret: Rails.application.credentials.dig(:missive, :webhook_secret)

# In your controller
class WebhooksController < ApplicationController
  def receive
    webhook_data = request.env['missive.webhook']
    
    case webhook_data[:type]
    when 'new_comment'
      handle_new_comment(webhook_data)
    when 'incoming_email'
      handle_incoming_email(webhook_data)
    end
    
    render json: { status: 'ok' }
  end
end
```

## Using the CLI

Install the CLI executable and use it for quick operations:

```bash
# Install the gem
gem install missive-rb

# Configure your API token (one-time setup)
echo "api_token: your-token-here" > ~/.missive.yml

# List teams
missive teams list --limit 10 --organization your-organization-id-here

# List users
missive users list --limit 20 --organization your-organization-id-here

# Create a task
missive tasks create \
  --title "Review customer feedback" \
  --team your-team-id-here \
  --organization your-organization-id-here \
  --description "Analyze the latest survey results"

# Update a task
missive tasks update \
  --id your-task-id-here \
  --state done \
  --title "Updated task title"

# Create a webhook
missive hooks create \
  --type new_comment \
  --url https://your-app.com/webhooks/comments \
  --organization your-organization-id-here

# Delete a webhook
missive hooks delete your-hook-id-here

# Sync contacts to stdout as JSON
missive contacts sync --since 2024-01-01 --limit 100

# Export conversation data
missive conversations export \
  --id your-conversation-id-here \
  --file conversation_backup.json

# Generate analytics report and wait for completion
missive analytics report \
  --type email_volume \
  --organization your-organization-id-here \
  --wait \
  --timeout 300
```

### CLI Configuration

The CLI reads configuration from `~/.missive.yml`:

```yaml
api_token: your-missive-api-token-here
```

Or use environment variables or command line flags:

```bash
# Environment variable
export MISSIVE_API_TOKEN=your-token-here
missive teams list

# Command line flag (highest priority)
missive teams list --token your-token-here
```

## HTTP Caching (Advanced)

Improve performance by enabling HTTP caching for GET requests. The library uses the industry-standard `faraday-http-cache` middleware to handle ETags and Last-Modified headers automatically.

### Enabling Caching

```ruby
require 'missive'

# Enable caching with default in-memory store
Missive.configure do |config|
  config.cache_enabled = true
end

client = Missive::Client.new(api_token: 'your_token_here')
```

### Using a Custom Cache Store

For production environments, use a shared cache store:

```ruby
require 'missive'
require 'active_support/cache'

# Use ActiveSupport's memory store
Missive.configure do |config|
  config.cache_enabled = true
  config.cache_store = ActiveSupport::Cache::MemoryStore.new
end

# Or use Redis for multi-process caching
# config.cache_store = ActiveSupport::Cache::RedisCacheStore.new(url: "redis://localhost:6379/1")

client = Missive::Client.new(api_token: 'your_token_here')
```

### Rails Integration

In a Rails application:

```ruby
# config/initializers/missive.rb
Missive.configure do |config|
  config.cache_enabled = true
  config.cache_store = Rails.cache  # Use Rails' configured cache store
end
```

### How Caching Works

- Only GET requests are cached
- Uses HTTP caching headers (ETag, Last-Modified) for validation
- Returns cached responses for repeated requests when data hasn't changed
- Automatically handles cache invalidation based on HTTP response headers
- Cache misses still make API calls but store the response for future use

**Note:** Caching is disabled by default to maintain backward compatibility. Enable it explicitly when you're ready to take advantage of the performance benefits.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/danmorin/missive-rb. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/danmorin/missive-rb/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Missive::Rb project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/danmorin/missive-rb/blob/main/CODE_OF_CONDUCT.md).
