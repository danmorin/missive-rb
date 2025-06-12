# Missive Ruby Client

A Ruby client library for the Missive API, providing thread-safe connection management, rate limiting, and comprehensive error handling.

## Resources Implemented

- **Analytics** - Create and retrieve analytics reports
- **Contacts** - Create, update, list, and retrieve contacts  
- **Contact Books** - List available contact books
- **Contact Groups** - List groups and organizations within contact books
- **Conversations** - List, retrieve conversations and access their messages and comments
- **Messages** - Create messages (for custom channels), retrieve messages, and search by email message ID
- **Drafts** - Create and send drafts
- **Posts** - Create and delete posts
- **SharedLabels** - Create, update, and list shared labels
- **Organizations** - List organizations
- **Responses** - List and retrieve response templates

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
    { id: "contact-id-1", first_name: "Jane" },
    { id: "contact-id-2", last_name: "Smith" }
  ]
)

# Get a specific contact
contact = client.contacts.get(id: "contact-id-here")
puts "#{contact.first_name} #{contact.last_name}"

# Iterate through all contacts with pagination
client.contacts.each_item(contact_book: "book-id-here") do |contact|
  puts "#{contact.email} - #{contact.first_name} #{contact.last_name}"
end
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
conversation = client.conversations.get(id: "c598d004-58d9-4e0f-9f27-c9f926ccf5aa")
puts "Subject: #{conversation.subject}"
puts "Messages count: #{conversation.messages_count}"

# Fetch messages within a conversation
messages = client.conversations.messages(
  conversation_id: conversation.id,
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
  conversation_id: conversation.id,
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
client.conversations.each_message(conversation_id: conversation.id) do |message|
  # Process each message
  puts "Message #{message.id}: #{message.subject}"
end
```

### Working with Messages

The Messages API allows you to retrieve individual messages, search by email message ID, and create messages for custom channels:

```ruby
# Get a specific message by ID
message = client.messages.get(id: "78e4a934-4401-3762-afd5-f54950b62528")
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
  channel_id: "fbf74c47-d0a0-4d77-bf3c-2118025d8102",
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

### Automating outbound drafts & sending

The Drafts API allows you to create and send drafts programmatically:

```ruby
# Create a draft
draft = client.drafts.create(
  body: "Hello! This is an automated response to your inquiry.",
  to_fields: [
    { name: "John Doe", address: "john@example.com" }
  ],
  from_field: { name: "Support Team", address: "support@company.com" },
  subject: "Re: Your inquiry about our services",
  attachments: [
    {
      name: "brochure.pdf",
      url: "https://storage.example.com/files/brochure.pdf"
    }
  ]
)

puts "Draft created: #{draft.id}"

# Send the draft immediately
sent_message = client.drafts.send_message(
  draft_id: draft.id,
  send_later: nil  # Send immediately
)

puts "Message sent: #{sent_message.id}"

# Or schedule for later (Unix timestamp)
scheduled = client.drafts.send_message(
  draft_id: draft.id,
  send_later: Time.now.to_i + 3600  # Send in 1 hour
)

puts "Message scheduled: #{scheduled.id}"
```

### Injecting webhook posts

The Posts API allows you to inject posts into conversations for webhook integrations:

```ruby
# Create a webhook post with markdown content
post = client.posts.create(
  text: nil,  # Use markdown instead
  markdown: "## Alert: Server Issue\n\n**Server:** web-01\n**Status:** High CPU usage detected\n**Time:** #{Time.now}",
  conversation: "c598d004-58d9-4e0f-9f27-c9f926ccf5aa",
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
  conversation: "c598d004-58d9-4e0f-9f27-c9f926ccf5aa"
)

# Delete a post if needed (e.g., false alarm)
client.posts.delete(id: post.id)
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
conversation_id = "c598d004-58d9-4e0f-9f27-c9f926ccf5aa"

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

## Managing tasks programmatically

The Tasks API allows you to create and update tasks programmatically:

```ruby
# Create a standalone task assigned to a team
task = client.tasks.create(
  title: "Follow up with client about proposal",
  team: "team-123",
  organization: "org-456",
  description: "Review the proposal and schedule a follow-up meeting",
  due_at: (Time.now + 7.days).iso8601
)

puts "Task created: #{task.id}"

# Create a subtask for a specific conversation
subtask = client.tasks.create(
  title: "Review attached documents",
  subtask: true,
  conversation: "conv-789",
  state: "todo"
)

# Update task status and details
updated_task = client.tasks.update(
  id: task.id,
  state: "done",
  title: "Updated: Follow up completed",
  description: "Meeting scheduled for next week"
)

puts "Task updated: #{updated_task.state}"
```

## Registering webhooks securely

The Hooks API and WebhookServer middleware provide secure webhook management:

```ruby
# Create webhooks for different events
comment_hook = client.hooks.create(
  type: "new_comment",
  url: "https://your-app.com/webhooks/comments",
  organization: "org-123"
)

email_hook = client.hooks.create(
  type: "incoming_email",
  url: "https://your-app.com/webhooks/emails",
  mailbox: "inbox-456"
)

# Delete a webhook when no longer needed
client.hooks.delete(id: comment_hook.id)
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
missive teams list --limit 10 --organization org-123

# Create a task
missive tasks create \
  --title "Review customer feedback" \
  --team team-456 \
  --organization org-123 \
  --description "Analyze the latest survey results"

# Delete a webhook
missive hooks delete hook-789
```

### CLI Configuration

The CLI reads configuration from `~/.missive.yml`:

```yaml
api_token: your-missive-api-token-here
```

Or use environment variables:

```bash
export MISSIVE_API_TOKEN=your-token-here
missive teams list
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
