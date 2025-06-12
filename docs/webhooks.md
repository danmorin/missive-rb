# Webhook Security and Integration Guide

This guide covers webhook signature validation, middleware integration, and common pitfalls when working with Missive webhooks.

## Overview

Missive webhooks provide real-time notifications for events in your organization. To ensure security and prevent tampering, all webhooks are signed with HMAC-SHA256.

## Setting Up Webhook Validation

### Basic Signature Validation

```ruby
require 'missive'

# Validate a webhook signature manually
payload = request.body.read
signature = request.headers['X-Missive-Signature']
secret = ENV['MISSIVE_WEBHOOK_SECRET']

if Missive::Signature.valid?(payload, signature, secret)
  # Process the webhook safely
  webhook_data = JSON.parse(payload)
  puts "Received #{webhook_data['type']} event"
else
  # Reject invalid webhook
  halt 403, "Invalid signature"
end
```

### Rack Middleware Integration

The recommended approach is using the `Missive::WebhookServer` middleware:

```ruby
# config.ru
require 'missive'

use Missive::WebhookServer, signature_secret: ENV['MISSIVE_WEBHOOK_SECRET']

app = lambda do |env|
  webhook_data = env['missive.webhook']
  
  if webhook_data
    case webhook_data[:type]
    when 'new_comment'
      handle_new_comment(webhook_data)
    when 'incoming_email'
      handle_incoming_email(webhook_data)
    when 'conversation_status_changed'
      handle_status_change(webhook_data)
    end
  end
  
  [200, { 'Content-Type' => 'application/json' }, [{ status: 'ok' }.to_json]]
end

run app
```

### Quick Mount Helper

For simple webhook endpoints:

```ruby
require 'missive'

# Mount a basic webhook receiver
app = Missive::WebhookServer.mount('/webhooks', ENV['MISSIVE_WEBHOOK_SECRET'])
run app
```

## Rails Integration

### Application Configuration

Add the middleware to your Rails application:

```ruby
# config/application.rb
class Application < Rails::Application
  config.middleware.use Missive::WebhookServer,
    signature_secret: Rails.application.credentials.dig(:missive, :webhook_secret)
end
```

### Controller Implementation

```ruby
# app/controllers/webhooks_controller.rb
class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def receive
    webhook_data = request.env['missive.webhook']
    
    return head :forbidden unless webhook_data
    
    WebhookProcessor.perform_async(webhook_data)
    
    render json: { status: 'received' }
  end
  
  private
  
  def webhook_params
    params.permit!
  end
end
```

### Background Processing

```ruby
# app/workers/webhook_processor.rb
class WebhookProcessor
  include Sidekiq::Worker
  
  def perform(webhook_data)
    case webhook_data['type']
    when 'new_comment'
      process_new_comment(webhook_data)
    when 'incoming_email'
      process_incoming_email(webhook_data)
    when 'conversation_assigned'
      process_assignment(webhook_data)
    end
  end
  
  private
  
  def process_new_comment(data)
    conversation_id = data.dig('comment', 'conversation', 'id')
    author = data.dig('comment', 'author', 'name')
    body = data.dig('comment', 'body')
    
    # Send notification
    SlackNotifier.notify(
      "New comment by #{author} on conversation #{conversation_id}: #{body.truncate(100)}"
    )
  end
  
  def process_incoming_email(data)
    message = data['message']
    from = message.dig('from_field', 'address')
    subject = message['subject']
    
    # Auto-assign based on sender
    if priority_customer?(from)
      assign_to_priority_team(message['id'])
    end
  end
end
```

## Sinatra Integration

```ruby
# app.rb
require 'sinatra'
require 'missive'

use Missive::WebhookServer, signature_secret: ENV['MISSIVE_WEBHOOK_SECRET']

post '/webhooks' do
  webhook_data = request.env['missive.webhook']
  
  halt 403, "Invalid webhook" unless webhook_data
  
  case webhook_data[:type]
  when 'new_comment'
    handle_comment(webhook_data)
  when 'incoming_email'
    handle_email(webhook_data)
  end
  
  { status: 'ok' }.to_json
end

def handle_comment(data)
  # Process comment webhook
  comment = data[:comment]
  logger.info "New comment: #{comment[:body]}"
end

def handle_email(data)
  # Process email webhook
  message = data[:message]
  logger.info "New email: #{message[:subject]}"
end
```

## Common Webhook Events

### New Comment

```json
{
  "type": "new_comment",
  "comment": {
    "id": "comment-123",
    "body": "This looks good to me!",
    "author": {
      "id": "user-456",
      "name": "John Doe",
      "email": "john@company.com"
    },
    "conversation": {
      "id": "conv-789",
      "subject": "Project proposal review"
    },
    "created_at": "2024-01-15T10:30:00Z"
  }
}
```

### Incoming Email

```json
{
  "type": "incoming_email",
  "message": {
    "id": "msg-123",
    "subject": "Support request",
    "from_field": {
      "name": "Customer Name",
      "address": "customer@example.com"
    },
    "to_fields": [
      {
        "name": "Support Team",
        "address": "support@company.com"
      }
    ],
    "body": "I need help with...",
    "created_at": "2024-01-15T10:30:00Z"
  }
}
```

### Conversation Status Changed

```json
{
  "type": "conversation_status_changed",
  "conversation": {
    "id": "conv-789",
    "subject": "Support ticket #12345",
    "status": "closed",
    "closed_at": "2024-01-15T15:45:00Z",
    "closed_by": {
      "id": "user-456",
      "name": "Support Agent"
    }
  }
}
```

## Security Best Practices

### 1. Always Validate Signatures

Never process webhooks without signature validation:

```ruby
# BAD - Never do this
post '/webhooks' do
  data = JSON.parse(request.body.read)
  process_webhook(data)  # Dangerous!
end

# GOOD - Always validate
use Missive::WebhookServer, signature_secret: ENV['MISSIVE_WEBHOOK_SECRET']

post '/webhooks' do
  webhook_data = request.env['missive.webhook']
  return halt 403 unless webhook_data
  
  process_webhook(webhook_data)  # Safe!
end
```

### 2. Use HTTPS Endpoints

Webhook URLs must use HTTPS in production:

```ruby
# Register webhook with HTTPS URL
client.hooks.create(
  type: "new_comment",
  url: "https://your-app.com/webhooks/comments"  # HTTPS required
)
```

### 3. Implement Idempotency

Webhooks may be delivered multiple times:

```ruby
def process_webhook(data)
  webhook_id = data['id']
  
  # Prevent duplicate processing
  return if ProcessedWebhook.exists?(webhook_id: webhook_id)
  
  ProcessedWebhook.create!(webhook_id: webhook_id)
  
  # Process the webhook...
end
```

### 4. Handle Failures Gracefully

Return appropriate HTTP status codes:

```ruby
post '/webhooks' do
  begin
    webhook_data = request.env['missive.webhook']
    return halt 403 unless webhook_data
    
    process_webhook(webhook_data)
    
    { status: 'ok' }.to_json
  rescue StandardError => e
    logger.error "Webhook processing failed: #{e.message}"
    halt 500, { error: 'Processing failed' }.to_json
  end
end
```

## Common Pitfalls

### 1. Raw Body Access Issues

The middleware consumes the request body. Access parsed data instead:

```ruby
# BAD - Body is already consumed
post '/webhooks' do
  raw_body = request.body.read  # This will be empty!
end

# GOOD - Use middleware-provided data
post '/webhooks' do
  webhook_data = request.env['missive.webhook']
end
```

### 2. JSON Parsing Errors

Let the middleware handle JSON parsing:

```ruby
# BAD - Manual parsing can fail
begin
  data = JSON.parse(request.body.read)
rescue JSON::ParserError => e
  halt 400, "Invalid JSON"
end

# GOOD - Middleware handles parsing and validation
webhook_data = request.env['missive.webhook']
halt 403 unless webhook_data
```

### 3. Blocking Operations

Don't perform slow operations in webhook handlers:

```ruby
# BAD - Slow operation blocks webhook
post '/webhooks' do
  webhook_data = request.env['missive.webhook']
  send_email_notification(webhook_data)  # Slow!
  update_crm_system(webhook_data)        # Even slower!
end

# GOOD - Queue for background processing
post '/webhooks' do
  webhook_data = request.env['missive.webhook']
  WebhookProcessor.perform_async(webhook_data)
  { status: 'queued' }.to_json
end
```

### 4. Missing Error Handling

Always handle webhook processing errors:

```ruby
# BAD - Unhandled errors cause webhook failures
def process_webhook(data)
  User.find(data.dig('user', 'id')).update!(last_seen: Time.now)
end

# GOOD - Handle missing data gracefully
def process_webhook(data)
  user_id = data.dig('user', 'id')
  return unless user_id
  
  user = User.find_by(id: user_id)
  return unless user
  
  user.update!(last_seen: Time.now)
rescue ActiveRecord::RecordInvalid => e
  logger.warn "Failed to update user #{user_id}: #{e.message}"
end
```

## Testing Webhooks

### Signature Generation

```ruby
# spec/support/webhook_helpers.rb
module WebhookHelpers
  def generate_webhook_signature(payload, secret)
    Missive::Signature.generate(payload, secret)
  end
  
  def post_webhook(path, payload, secret = 'test-secret')
    signature = generate_webhook_signature(payload, secret)
    
    post path, payload, {
      'HTTP_X_MISSIVE_SIGNATURE' => signature,
      'CONTENT_TYPE' => 'application/json'
    }
  end
end
```

### RSpec Examples

```ruby
# spec/requests/webhooks_spec.rb
RSpec.describe "Webhooks", type: :request do
  include WebhookHelpers
  
  let(:webhook_payload) do
    {
      type: 'new_comment',
      comment: {
        id: 'comment-123',
        body: 'Test comment'
      }
    }.to_json
  end
  
  it "processes valid webhooks" do
    expect(WebhookProcessor).to receive(:perform_async)
    
    post_webhook('/webhooks', webhook_payload)
    
    expect(response).to have_http_status(:ok)
  end
  
  it "rejects invalid signatures" do
    post '/webhooks', webhook_payload, {
      'HTTP_X_MISSIVE_SIGNATURE' => 'invalid-signature',
      'CONTENT_TYPE' => 'application/json'
    }
    
    expect(response).to have_http_status(:forbidden)
  end
end
```

## Monitoring and Debugging

### Webhook Delivery Logs

Monitor webhook delivery success:

```ruby
class WebhookLogger
  def self.log_webhook(request, response_status)
    webhook_data = request.env['missive.webhook']
    
    Rails.logger.info({
      event: 'webhook_received',
      type: webhook_data&.dig(:type),
      signature_valid: webhook_data.present?,
      response_status: response_status,
      timestamp: Time.current
    }.to_json)
  end
end

# In your webhook handler
post '/webhooks' do
  webhook_data = request.env['missive.webhook']
  
  if webhook_data
    process_webhook(webhook_data)
    status = 200
  else
    status = 403
  end
  
  WebhookLogger.log_webhook(request, status)
  
  halt status
end
```

### Health Check Endpoint

Provide a health check for webhook monitoring:

```ruby
get '/webhooks/health' do
  {
    status: 'healthy',
    timestamp: Time.current.iso8601,
    version: MyApp::VERSION
  }.to_json
end
```