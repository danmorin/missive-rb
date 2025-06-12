# frozen_string_literal: true

# Helper module for managing ActiveSupport::Notifications in tests
module NotificationsHelper
  # Use this to manually manage notification isolation
  def with_isolated_notifications
    original_notifier = ActiveSupport::Notifications.notifier
    # Create a fresh notifier for this test to avoid cross-test contamination
    ActiveSupport::Notifications.notifier = ActiveSupport::Notifications::Fanout.new
    yield
  ensure
    # Restore the original notifier
    ActiveSupport::Notifications.notifier = original_notifier
  end

  # Helper method to allow instrumentation blocks to execute
  def allow_notifications_to_execute
    allow(ActiveSupport::Notifications).to receive(:instrument) do |_event, _payload, &block|
      block&.call
    end
  end

  # Helper method for testing instrumentation calls
  def expect_notification(event_name, expected_payload = {})
    received_events = []

    allow(ActiveSupport::Notifications).to receive(:instrument) do |event, payload, &block|
      received_events << { event: event, payload: payload }
      block&.call
    end

    yield if block_given?

    matching_events = received_events.select { |e| e[:event] == event_name }
    expect(matching_events).not_to be_empty, "Expected notification '#{event_name}' but none was sent"

    return unless expected_payload.any?

    expect(matching_events.last[:payload]).to include(expected_payload)
  end
end

RSpec.configure do |config|
  config.include NotificationsHelper
end
