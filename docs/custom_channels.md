# Custom Channels Guide

This guide covers sending and validating messages through Missive's custom channels feature, which allows you to integrate external messaging platforms and services.

## Overview

Custom channels in Missive allow you to:
- Integrate with external messaging platforms (Slack, Discord, WhatsApp, etc.)
- Build custom communication workflows
- Centralize conversations from multiple sources
- Maintain conversation context across platforms

## Setting Up Custom Channels

### Creating a Custom Channel

First, create a custom channel in your Missive organization through the web interface:

1. Go to Settings → Integrations → Custom Channels
2. Click "Add Custom Channel"
3. Configure the channel name, icon, and webhook URL
4. Note the channel ID for API usage

### Channel Configuration

```ruby
# Example channel configuration
CUSTOM_CHANNEL_CONFIG = {
  slack_support: {
    id: 'fbf74c47-d0a0-4d77-bf3c-2118025d8102',
    name: 'Slack Support',
    webhook_secret: ENV['SLACK_WEBHOOK_SECRET']
  },
  whatsapp_business: {
    id: 'a8e3b2c1-5f4d-4a2b-9c8e-1234567890ab',
    name: 'WhatsApp Business',
    webhook_secret: ENV['WHATSAPP_WEBHOOK_SECRET']
  }
}.freeze
```

## Sending Messages to Custom Channels

### Basic Message Creation

```ruby
require 'missive'

client = Missive::Client.new(api_token: ENV['MISSIVE_API_TOKEN'])

# Send a message to a custom channel
message = client.messages.create_for_custom_channel(
  channel_id: 'fbf74c47-d0a0-4d77-bf3c-2118025d8102',
  from_field: {
    id: 'user_12345',
    username: '@john_doe',
    name: 'John Doe'
  },
  to_fields: [
    {
      id: 'channel_general',
      username: '#general',
      name: 'General Channel'
    }
  ],
  body: 'Hello from our custom integration!',
  subject: 'Integration Test Message'
)

puts "Message created: #{message.id}"
```

### Advanced Message Features

```ruby
# Message with rich formatting and attachments
rich_message = client.messages.create_for_custom_channel(
  channel_id: 'fbf74c47-d0a0-4d77-bf3c-2118025d8102',
  from_field: {
    id: 'bot_system',
    username: '@system_bot',
    name: 'System Bot',
    avatar_url: 'https://example.com/bot-avatar.png'
  },
  to_fields: [
    {
      id: 'user_12345',
      username: '@john_doe',
      name: 'John Doe'
    }
  ],
  body: "**Alert**: Server monitoring detected high CPU usage\n\n" \
        "- Server: web-01\n" \
        "- CPU Usage: 95%\n" \
        "- Timestamp: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}\n\n" \
        "Please check the attached monitoring report.",
  subject: 'High CPU Alert - web-01',
  attachments: [
    {
      name: 'cpu_report.png',
      url: 'https://monitoring.example.com/reports/cpu_report.png',
      content_type: 'image/png'
    },
    {
      name: 'system_logs.txt',
      url: 'https://logs.example.com/web-01/latest.txt',
      content_type: 'text/plain'
    }
  ],
  metadata: {
    priority: 'high',
    alert_id: 'alert_789',
    server_id: 'web-01'
  }
)
```

## Platform-Specific Integrations

### Slack Integration

```ruby
class SlackToMissive
  def initialize(missive_client, channel_id)
    @missive = missive_client
    @channel_id = channel_id
  end
  
  def handle_slack_message(slack_event)
    # Convert Slack message to Missive format
    message = @missive.messages.create_for_custom_channel(
      channel_id: @channel_id,
      from_field: {
        id: slack_event['user'],
        username: "@#{slack_event['user']}",
        name: lookup_slack_user_name(slack_event['user'])
      },
      to_fields: [
        {
          id: slack_event['channel'],
          username: "##{lookup_channel_name(slack_event['channel'])}",
          name: lookup_channel_name(slack_event['channel'])
        }
      ],
      body: convert_slack_formatting(slack_event['text']),
      subject: "Slack: #{lookup_channel_name(slack_event['channel'])}",
      attachments: process_slack_attachments(slack_event['files']),
      metadata: {
        slack_ts: slack_event['ts'],
        slack_channel: slack_event['channel'],
        thread_ts: slack_event['thread_ts']
      }
    )
    
    message
  end
  
  private
  
  def convert_slack_formatting(text)
    text.gsub(/<@(\w+)>/) { |match| "@#{lookup_slack_user_name($1)}" }
        .gsub(/<#(\w+)\|([^>]+)>/) { |match| "##{$2}" }
        .gsub(/```([^`]+)```/) { |match| "```\n#{$1}\n```" }
  end
  
  def process_slack_attachments(files)
    return [] unless files
    
    files.map do |file|
      {
        name: file['name'],
        url: file['url_private'],
        content_type: file['mimetype']
      }
    end
  end
  
  def lookup_slack_user_name(user_id)
    # Integration with Slack API to get user name
    "User_#{user_id}"
  end
  
  def lookup_channel_name(channel_id)
    # Integration with Slack API to get channel name
    "Channel_#{channel_id}"
  end
end
```

### WhatsApp Business Integration

```ruby
class WhatsAppToMissive
  def initialize(missive_client, channel_id)
    @missive = missive_client
    @channel_id = channel_id
  end
  
  def handle_whatsapp_message(wa_webhook)
    message_data = wa_webhook['messages']&.first
    return unless message_data
    
    contact_info = wa_webhook['contacts']&.first
    
    message = @missive.messages.create_for_custom_channel(
      channel_id: @channel_id,
      from_field: {
        id: message_data['from'],
        username: message_data['from'],
        name: contact_info&.dig('profile', 'name') || message_data['from']
      },
      to_fields: [
        {
          id: 'whatsapp_business',
          username: 'WhatsApp Business',
          name: 'WhatsApp Business Account'
        }
      ],
      body: extract_whatsapp_content(message_data),
      subject: "WhatsApp: #{contact_info&.dig('profile', 'name') || message_data['from']}",
      attachments: process_whatsapp_media(message_data),
      metadata: {
        whatsapp_id: message_data['id'],
        phone_number: message_data['from'],
        message_type: message_data['type']
      }
    )
    
    message
  end
  
  private
  
  def extract_whatsapp_content(message_data)
    case message_data['type']
    when 'text'
      message_data.dig('text', 'body')
    when 'image'
      caption = message_data.dig('image', 'caption')
      caption ? "Image: #{caption}" : "Image message"
    when 'document'
      filename = message_data.dig('document', 'filename')
      "Document: #{filename}"
    when 'audio'
      "Voice message"
    when 'location'
      lat = message_data.dig('location', 'latitude')
      lng = message_data.dig('location', 'longitude')
      "Location: #{lat}, #{lng}"
    else
      "#{message_data['type'].capitalize} message"
    end
  end
  
  def process_whatsapp_media(message_data)
    attachments = []
    
    %w[image document audio video].each do |media_type|
      if message_data[media_type]
        media = message_data[media_type]
        attachments << {
          name: media['filename'] || "#{media_type}_#{message_data['id']}",
          url: download_whatsapp_media(media['id']),
          content_type: media['mime_type']
        }
      end
    end
    
    attachments
  end
  
  def download_whatsapp_media(media_id)
    # Integration with WhatsApp Business API to download media
    "https://api.whatsapp.example.com/media/#{media_id}"
  end
end
```

### Discord Integration

```ruby
class DiscordToMissive
  def initialize(missive_client, channel_id)
    @missive = missive_client
    @channel_id = channel_id
  end
  
  def handle_discord_message(discord_event)
    message = @missive.messages.create_for_custom_channel(
      channel_id: @channel_id,
      from_field: {
        id: discord_event['author']['id'],
        username: discord_event['author']['username'],
        name: discord_event['author']['global_name'] || discord_event['author']['username']
      },
      to_fields: [
        {
          id: discord_event['channel_id'],
          username: "##{lookup_discord_channel_name(discord_event['channel_id'])}",
          name: lookup_discord_channel_name(discord_event['channel_id'])
        }
      ],
      body: convert_discord_formatting(discord_event['content']),
      subject: "Discord: #{lookup_discord_channel_name(discord_event['channel_id'])}",
      attachments: process_discord_attachments(discord_event['attachments']),
      metadata: {
        discord_id: discord_event['id'],
        channel_id: discord_event['channel_id'],
        guild_id: discord_event['guild_id']
      }
    )
    
    message
  end
  
  private
  
  def convert_discord_formatting(content)
    content.gsub(/<@!?(\d+)>/) { |match| "@#{lookup_discord_user_name($1)}" }
           .gsub(/<#(\d+)>/) { |match| "##{lookup_discord_channel_name($1)}" }
           .gsub(/```([^`]+)```/) { |match| "```\n#{$1}\n```" }
           .gsub(/`([^`]+)`/) { |match| "`#{$1}`" }
  end
  
  def process_discord_attachments(attachments)
    return [] unless attachments
    
    attachments.map do |attachment|
      {
        name: attachment['filename'],
        url: attachment['url'],
        content_type: attachment['content_type']
      }
    end
  end
  
  def lookup_discord_user_name(user_id)
    # Integration with Discord API
    "User_#{user_id}"
  end
  
  def lookup_discord_channel_name(channel_id)
    # Integration with Discord API
    "Channel_#{channel_id}"
  end
end
```

## Message Validation and Error Handling

### Input Validation

```ruby
class CustomChannelValidator
  REQUIRED_FIELDS = %i[channel_id from_field to_fields body].freeze
  MAX_BODY_LENGTH = 10_000
  MAX_SUBJECT_LENGTH = 255
  MAX_ATTACHMENTS = 10
  
  def self.validate_message(params)
    errors = []
    
    # Required field validation
    REQUIRED_FIELDS.each do |field|
      errors << "#{field} is required" unless params[field]
    end
    
    # Field format validation
    errors.concat(validate_from_field(params[:from_field])) if params[:from_field]
    errors.concat(validate_to_fields(params[:to_fields])) if params[:to_fields]
    errors.concat(validate_body(params[:body])) if params[:body]
    errors.concat(validate_subject(params[:subject])) if params[:subject]
    errors.concat(validate_attachments(params[:attachments])) if params[:attachments]
    
    errors
  end
  
  private
  
  def self.validate_from_field(from_field)
    errors = []
    errors << "from_field.id is required" unless from_field[:id]
    errors << "from_field.name is required" unless from_field[:name]
    errors
  end
  
  def self.validate_to_fields(to_fields)
    errors = []
    errors << "to_fields must be an array" unless to_fields.is_a?(Array)
    errors << "at least one to_field is required" if to_fields.empty?
    
    to_fields.each_with_index do |field, index|
      errors << "to_fields[#{index}].id is required" unless field[:id]
      errors << "to_fields[#{index}].name is required" unless field[:name]
    end
    
    errors
  end
  
  def self.validate_body(body)
    errors = []
    errors << "body cannot be empty" if body.strip.empty?
    errors << "body is too long (maximum #{MAX_BODY_LENGTH} characters)" if body.length > MAX_BODY_LENGTH
    errors
  end
  
  def self.validate_subject(subject)
    errors = []
    errors << "subject is too long (maximum #{MAX_SUBJECT_LENGTH} characters)" if subject.length > MAX_SUBJECT_LENGTH
    errors
  end
  
  def self.validate_attachments(attachments)
    errors = []
    errors << "too many attachments (maximum #{MAX_ATTACHMENTS})" if attachments.length > MAX_ATTACHMENTS
    
    attachments.each_with_index do |attachment, index|
      errors << "attachments[#{index}].name is required" unless attachment[:name]
      errors << "attachments[#{index}].url is required" unless attachment[:url]
    end
    
    errors
  end
end

# Usage
def send_validated_message(params)
  errors = CustomChannelValidator.validate_message(params)
  
  if errors.any?
    raise ArgumentError, "Invalid message parameters: #{errors.join(', ')}"
  end
  
  client.messages.create_for_custom_channel(**params)
end
```

### Error Handling and Retries

```ruby
class CustomChannelService
  include Retryable
  
  def initialize(missive_client)
    @client = missive_client
  end
  
  def send_message_with_retry(params)
    retryable(
      tries: 3,
      on: [Missive::RateLimitError, Missive::ServerError],
      sleep: ->(n) { 2**n }  # Exponential backoff
    ) do
      @client.messages.create_for_custom_channel(**params)
    end
  rescue Missive::AuthenticationError => e
    logger.error "Authentication failed: #{e.message}"
    raise
  rescue Missive::NotFoundError => e
    logger.error "Channel not found: #{e.message}"
    raise
  rescue StandardError => e
    logger.error "Unexpected error sending message: #{e.message}"
    raise
  end
  
  def send_bulk_messages(messages)
    results = []
    
    messages.each_with_index do |message_params, index|
      begin
        result = send_message_with_retry(message_params)
        results << { index: index, success: true, message_id: result.id }
        
        # Rate limiting: small delay between messages
        sleep(0.1) unless index == messages.length - 1
      rescue StandardError => e
        results << { index: index, success: false, error: e.message }
        logger.error "Failed to send message #{index}: #{e.message}"
      end
    end
    
    results
  end
end
```

## Testing Custom Channels

### RSpec Testing

```ruby
# spec/services/custom_channel_service_spec.rb
RSpec.describe CustomChannelService do
  let(:missive_client) { instance_double(Missive::Client) }
  let(:messages_resource) { instance_double(Missive::Resources::Messages) }
  let(:service) { described_class.new(missive_client) }
  
  before do
    allow(missive_client).to receive(:messages).and_return(messages_resource)
  end
  
  describe '#send_message_with_retry' do
    let(:message_params) do
      {
        channel_id: 'test-channel',
        from_field: { id: 'user1', name: 'Test User' },
        to_fields: [{ id: 'channel1', name: 'Test Channel' }],
        body: 'Test message'
      }
    end
    
    let(:message_response) { double('Message', id: 'msg-123') }
    
    it 'sends message successfully' do
      expect(messages_resource).to receive(:create_for_custom_channel)
        .with(**message_params)
        .and_return(message_response)
      
      result = service.send_message_with_retry(message_params)
      expect(result.id).to eq('msg-123')
    end
    
    it 'retries on rate limit errors' do
      expect(messages_resource).to receive(:create_for_custom_channel)
        .twice
        .and_raise(Missive::RateLimitError.new('Rate limited'))
        .then
        .and_return(message_response)
      
      result = service.send_message_with_retry(message_params)
      expect(result.id).to eq('msg-123')
    end
    
    it 'does not retry on authentication errors' do
      expect(messages_resource).to receive(:create_for_custom_channel)
        .once
        .and_raise(Missive::AuthenticationError.new('Invalid token'))
      
      expect {
        service.send_message_with_retry(message_params)
      }.to raise_error(Missive::AuthenticationError)
    end
  end
end
```

### Integration Testing

```ruby
# spec/integration/custom_channel_integration_spec.rb
RSpec.describe 'Custom Channel Integration', type: :integration do
  let(:client) { Missive::Client.new(api_token: test_api_token) }
  let(:channel_id) { 'test-channel-id' }
  
  before do
    # Stub HTTP requests to Missive API
    stub_request(:post, %r{#{Missive::Constants::BASE_URL}/messages})
      .to_return(
        status: 200,
        body: { id: 'msg-123', type: 'message' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
  
  it 'creates custom channel message' do
    message = client.messages.create_for_custom_channel(
      channel_id: channel_id,
      from_field: { id: 'user1', name: 'Test User' },
      to_fields: [{ id: 'channel1', name: 'Test Channel' }],
      body: 'Integration test message'
    )
    
    expect(message.id).to eq('msg-123')
  end
end
```

## Monitoring and Analytics

### Message Tracking

```ruby
class CustomChannelTracker
  def self.track_message(channel_id, message_id, metadata = {})
    Rails.logger.info({
      event: 'custom_channel_message_sent',
      channel_id: channel_id,
      message_id: message_id,
      timestamp: Time.current,
      metadata: metadata
    }.to_json)
    
    # Track in analytics service
    Analytics.track('Custom Channel Message', {
      channel_id: channel_id,
      message_id: message_id,
      **metadata
    })
  end
  
  def self.track_error(channel_id, error, metadata = {})
    Rails.logger.error({
      event: 'custom_channel_error',
      channel_id: channel_id,
      error: error.message,
      error_class: error.class.name,
      timestamp: Time.current,
      metadata: metadata
    }.to_json)
  end
end
```

### Performance Monitoring

```ruby
class CustomChannelPerformance
  def self.monitor_send_performance
    start_time = Time.current
    
    yield
    
    duration = Time.current - start_time
    
    Rails.logger.info({
      event: 'custom_channel_performance',
      duration_ms: (duration * 1000).round(2),
      timestamp: Time.current
    }.to_json)
    
    # Alert if performance is degraded
    if duration > 5.seconds
      AlertService.notify("Custom channel message sending is slow: #{duration}s")
    end
  end
end

# Usage
CustomChannelPerformance.monitor_send_performance do
  service.send_message_with_retry(message_params)
end
```

## Best Practices

### 1. Message Formatting Consistency

Maintain consistent formatting across different platforms:

```ruby
class MessageFormatter
  def self.normalize_content(content, source_platform)
    case source_platform
    when 'slack'
      normalize_slack_format(content)
    when 'discord'
      normalize_discord_format(content)
    when 'whatsapp'
      normalize_whatsapp_format(content)
    else
      content
    end
  end
  
  private
  
  def self.normalize_slack_format(content)
    content.gsub(/<@(\w+)>/, '@\1')
           .gsub(/<#(\w+)\|([^>]+)>/, '#\2')
  end
  
  def self.normalize_discord_format(content)
    content.gsub(/<@!?(\d+)>/, '@\1')
           .gsub(/<#(\d+)>/, '#\1')
  end
  
  def self.normalize_whatsapp_format(content)
    # WhatsApp doesn't have special formatting to normalize
    content
  end
end
```

### 2. Rate Limiting and Throttling

Implement client-side rate limiting:

```ruby
class CustomChannelRateLimiter
  def initialize(requests_per_minute: 60)
    @requests_per_minute = requests_per_minute
    @requests = []
    @mutex = Mutex.new
  end
  
  def throttle
    @mutex.synchronize do
      now = Time.current
      
      # Remove requests older than 1 minute
      @requests.reject! { |timestamp| timestamp < now - 1.minute }
      
      if @requests.length >= @requests_per_minute
        sleep_time = 60.0 / @requests_per_minute
        sleep(sleep_time)
      end
      
      @requests << now
    end
    
    yield
  end
end
```

### 3. Message Deduplication

Prevent duplicate messages:

```ruby
class MessageDeduplicator
  def initialize(redis_client)
    @redis = redis_client
  end
  
  def deduplicate(platform_message_id, &block)
    key = "custom_channel:processed:#{platform_message_id}"
    
    # Try to set the key with expiration
    if @redis.set(key, '1', ex: 3600, nx: true)  # 1 hour expiration
      block.call
    else
      Rails.logger.info "Skipping duplicate message: #{platform_message_id}"
    end
  end
end
```