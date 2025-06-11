# frozen_string_literal: true

require "spec_helper"
require "timecop"

RSpec.describe Missive::Resources::Analytics do
  let(:client) { instance_double("Missive::Client") }
  let(:connection) { instance_double("Missive::Connection") }
  let(:analytics) { described_class.new(client) }

  before do
    allow(client).to receive(:connection).and_return(connection)
  end

  describe "#initialize" do
    it "stores the client" do
      expect(analytics.instance_variable_get(:@client)).to eq(client)
    end
  end

  describe "#create_report" do
    let(:report_data) do
      { reports: { "id" => "report123", "organization" => "0d9bab85-a74f-4ece-9142-0f9b9f36ff92", "status" => "pending" } }
    end

    it "sends POST request with correct payload" do
      expected_payload = {
        reports: {
          organization: "0d9bab85-a74f-4ece-9142-0f9b9f36ff92",
          start: 1_691_812_800,
          end: 1_692_371_867
        }
      }

      allow(connection).to receive(:request).with(:post, "/analytics/reports",
                                                  body: expected_payload).and_return(report_data)

      result = analytics.create_report(
        organization: "0d9bab85-a74f-4ece-9142-0f9b9f36ff92",
        start_time: 1_691_812_800,
        end_time: 1_692_371_867
      )

      expect(connection).to have_received(:request).with(:post, "/analytics/reports",
                                                         body: expected_payload)
      expect(result).to be_a(Missive::Object)
      expect(result.id).to eq("report123")
    end

    it "includes additional parameters in reports object" do
      expected_payload = {
        reports: {
          organization: "0d9bab85-a74f-4ece-9142-0f9b9f36ff92",
          start: 1_691_812_800,
          end: 1_692_371_867,
          time_zone: "America/Montreal",
          teams: ["team1"]
        }
      }

      allow(connection).to receive(:request).with(:post, "/analytics/reports",
                                                  body: expected_payload).and_return(report_data)

      analytics.create_report(
        organization: "0d9bab85-a74f-4ece-9142-0f9b9f36ff92",
        start_time: 1_691_812_800,
        end_time: 1_692_371_867,
        time_zone: "America/Montreal",
        teams: ["team1"]
      )

      expect(connection).to have_received(:request).with(:post, "/analytics/reports",
                                                         body: expected_payload)
    end

    it "raises ArgumentError when organization is nil" do
      expect do
        analytics.create_report(organization: nil, start_time: 1_691_812_800, end_time: 1_692_371_867)
      end.to raise_error(ArgumentError, "organization is required")
    end

    it "raises ArgumentError when organization is empty" do
      expect do
        analytics.create_report(organization: "", start_time: 1_691_812_800, end_time: 1_692_371_867)
      end.to raise_error(ArgumentError, "organization is required")
    end

    it "raises ArgumentError when start_time is nil" do
      expect do
        analytics.create_report(organization: "0d9bab85-a74f-4ece-9142-0f9b9f36ff92", start_time: nil, end_time: 1_692_371_867)
      end.to raise_error(ArgumentError, "start_time is required")
    end

    it "raises ArgumentError when end_time is nil" do
      expect do
        analytics.create_report(organization: "0d9bab85-a74f-4ece-9142-0f9b9f36ff92", start_time: 1_691_812_800, end_time: nil)
      end.to raise_error(ArgumentError, "end_time is required")
    end

    it "emits missive.analytics.create_report notification" do
      expected_payload = {
        reports: {
          organization: "0d9bab85-a74f-4ece-9142-0f9b9f36ff92",
          start: 1_691_812_800,
          end: 1_692_371_867
        }
      }

      allow(connection).to receive(:request).with(:post, "/analytics/reports",
                                                  body: expected_payload).and_return(report_data)

      notifications = []
      ActiveSupport::Notifications.subscribe("missive.analytics.create_report") do |name, _start, _finish, _id, payload|
        notifications << { name: name, payload: payload }
      end

      analytics.create_report(
        organization: "0d9bab85-a74f-4ece-9142-0f9b9f36ff92",
        start_time: 1_691_812_800,
        end_time: 1_692_371_867
      )

      expect(notifications).not_to be_empty
      expect(notifications.first[:name]).to eq("missive.analytics.create_report")
    end

    it "handles server errors by letting them bubble up" do
      allow(connection).to receive(:request).and_raise(Missive::ServerError.new("Bad Request"))

      expect do
        analytics.create_report(
          organization: "0d9bab85-a74f-4ece-9142-0f9b9f36ff92",
          start_time: 1_691_812_800,
          end_time: 1_692_371_867
        )
      end.to raise_error(Missive::ServerError)
    end

    it "flattens nested reports structure for easier access" do
      nested_response = { reports: { "id" => "report123", "status" => "pending" } }
      allow(connection).to receive(:request).with(:post, "/analytics/reports",
                                                  body: anything).and_return(nested_response)

      result = analytics.create_report(
        organization: "0d9bab85-a74f-4ece-9142-0f9b9f36ff92",
        start_time: 1_691_812_800,
        end_time: 1_692_371_867
      )

      expect(result.id).to eq("report123")
      expect(result.status).to eq("pending")
    end

    it "handles non-nested response structure" do
      flat_response = { "id" => "report456", "status" => "done" }
      allow(connection).to receive(:request).with(:post, "/analytics/reports",
                                                  body: anything).and_return(flat_response)

      result = analytics.create_report(
        organization: "0d9bab85-a74f-4ece-9142-0f9b9f36ff92",
        start_time: 1_691_812_800,
        end_time: 1_692_371_867
      )

      expect(result.id).to eq("report456")
      expect(result.status).to eq("done")
    end
  end

  describe "#get_report" do
    let(:report_data) { { reports: { "id" => "report123", "type" => "conversations", "status" => "done" } } }

    it "sends GET request to correct path" do
      allow(connection).to receive(:request).with(:get, "/analytics/reports/report123").and_return(report_data)

      result = analytics.get_report(report_id: "report123")

      expect(connection).to have_received(:request).with(:get, "/analytics/reports/report123")
      expect(result).to be_a(Missive::Object)
      expect(result.id).to eq("report123")
    end

    it "handles integer report_id" do
      allow(connection).to receive(:request).with(:get, "/analytics/reports/123").and_return(report_data)

      analytics.get_report(report_id: 123)

      expect(connection).to have_received(:request).with(:get, "/analytics/reports/123")
    end

    it "raises ArgumentError when report_id is nil" do
      expect { analytics.get_report(report_id: nil) }.to raise_error(ArgumentError, "report_id is required")
    end

    it "emits missive.analytics.get_report notification" do
      allow(connection).to receive(:request).with(:get, "/analytics/reports/report123").and_return(report_data)

      notifications = []
      ActiveSupport::Notifications.subscribe("missive.analytics.get_report") do |name, _start, _finish, _id, payload|
        notifications << { name: name, payload: payload }
      end

      analytics.get_report(report_id: "report123")

      expect(notifications).not_to be_empty
      expect(notifications.first[:name]).to eq("missive.analytics.get_report")
    end

    it "flattens nested reports structure for easier access" do
      nested_response = { reports: { "id" => "report123", "status" => "done" } }
      allow(connection).to receive(:request).with(:get, "/analytics/reports/report123").and_return(nested_response)

      result = analytics.get_report(report_id: "report123")

      expect(result.id).to eq("report123")
      expect(result.status).to eq("done")
    end

    it "handles non-nested response structure" do
      flat_response = { "id" => "report456", "status" => "pending" }
      allow(connection).to receive(:request).with(:get, "/analytics/reports/report456").and_return(flat_response)

      result = analytics.get_report(report_id: "report456")

      expect(result.id).to eq("report456")
      expect(result.status).to eq("pending")
    end
  end

  describe "#wait_for_report" do
    let(:completed_report_data) { { "start" => 1_691_812_800, "end" => 1_692_371_867, "metrics" => {} } }

    it "polls until report data is available" do
      Timecop.freeze do
        call_count = 0
        allow(analytics).to receive(:get_report).with(report_id: "report123") do
          call_count += 1
          raise Missive::NotFoundError, "Report not ready" if call_count < 3

          Missive::Object.new(completed_report_data)
        end
        allow(analytics).to receive(:wait_interval)

        result = analytics.wait_for_report(report_id: "report123", interval: 0.01)

        expect(analytics).to have_received(:get_report).exactly(3).times
        expect(result.start).to eq(1_691_812_800)
        expect(result.end).to eq(1_692_371_867)
      end
    end

    it "sleeps for specified interval between polls" do
      Timecop.freeze do
        call_count = 0
        allow(analytics).to receive(:get_report).with(report_id: "report123") do
          call_count += 1
          raise Missive::NotFoundError, "Report not ready" if call_count < 2

          Missive::Object.new(completed_report_data)
        end
        allow(analytics).to receive(:wait_interval)

        analytics.wait_for_report(report_id: "report123", interval: 0.5)

        expect(analytics).to have_received(:wait_interval).with(0.5)
      end
    end

    it "raises Timeout::Error when timeout exceeded" do
      Timecop.freeze do
        allow(analytics).to receive(:get_report).with(report_id: "report123") do
          raise Missive::NotFoundError, "Report not ready"
        end
        allow(analytics).to receive(:wait_interval) do
          Timecop.travel(2) # Advance time by 2 seconds each sleep
        end

        expect do
          analytics.wait_for_report(report_id: "report123", interval: 0.01, timeout: 1)
        end.to raise_error(Timeout::Error, "Report did not complete within 1 seconds")
      end
    end

    it "raises ArgumentError when report_id is nil" do
      expect { analytics.wait_for_report(report_id: nil) }.to raise_error(ArgumentError, "report_id is required")
    end

    it "emits missive.analytics.wait_for_report notification with iterations count" do
      Timecop.freeze do
        call_count = 0
        allow(analytics).to receive(:get_report).with(report_id: "report123") do
          call_count += 1
          raise Missive::NotFoundError, "Report not ready" if call_count < 2

          Missive::Object.new(completed_report_data)
        end
        allow(analytics).to receive(:wait_interval)

        notifications = []
        ActiveSupport::Notifications.subscribe("missive.analytics.wait_for_report") do |name, _start, _finish, _id, payload|
          notifications << { name: name, payload: payload }
        end

        analytics.wait_for_report(report_id: "report123", interval: 0.01)

        expect(notifications).not_to be_empty
        expect(notifications.first[:name]).to eq("missive.analytics.wait_for_report")
        expect(notifications.first[:payload]).to include(iterations: 2)
      end
    end

    it "uses default values for interval and timeout" do
      Timecop.freeze do
        allow(analytics).to receive(:get_report).with(report_id: "report123")
                                                .and_return(Missive::Object.new(completed_report_data))

        result = analytics.wait_for_report(report_id: "report123")

        expect(result.start).to eq(1_691_812_800)
      end
    end

    it "returns report immediately if already available" do
      Timecop.freeze do
        allow(analytics).to receive(:get_report).with(report_id: "report123")
                                                .and_return(Missive::Object.new(completed_report_data))
        allow(analytics).to receive(:wait_interval)

        result = analytics.wait_for_report(report_id: "report123")

        expect(analytics).to have_received(:get_report).once
        expect(analytics).not_to have_received(:wait_interval)
        expect(result.start).to eq(1_691_812_800)
      end
    end

    it "actually calls sleep through wait_interval" do
      Timecop.freeze do
        call_count = 0
        allow(analytics).to receive(:get_report).with(report_id: "report123") do
          call_count += 1
          raise Missive::NotFoundError, "Report not ready" if call_count < 2

          Missive::Object.new(completed_report_data)
        end
        # Don't mock wait_interval, but mock the actual sleep method
        allow(analytics).to receive(:sleep)

        analytics.wait_for_report(report_id: "report123", interval: 0.01)

        expect(analytics).to have_received(:sleep).with(0.01)
      end
    end
  end
end
