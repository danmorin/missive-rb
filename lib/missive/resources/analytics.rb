# frozen_string_literal: true

require "timeout"
require "active_support"
require "json"

module Missive
  module Resources
    # @!method create_report(organization:, start_time:, end_time:, **params)
    #   Creates a new analytics report
    #   @param organization [String] Organization ID (required)
    #   @param start_time [Integer] Unix timestamp for report period start (required)
    #   @param end_time [Integer] Unix timestamp for report period end (required)
    #   @param params [Hash] Additional optional parameters (time_zone, teams, users, shared_labels, accounts, account_types)
    #   @return [Missive::Object] The created report object
    #   @example
    #     client.analytics.create_report(
    #       organization: '0d9bab85-a74f-4ece-9142-0f9b9f36ff92',
    #       start_time: 1691812800,
    #       end_time: 1692371867,
    #       time_zone: 'America/Montreal'
    #     )
    #
    # @!method get_report(report_id:)
    #   Retrieves an analytics report by ID
    #   @param report_id [String, Integer] The ID of the report to retrieve
    #   @return [Missive::Object] The report object
    #   @example
    #     client.analytics.get_report(report_id: 'abc123')
    #
    # @!method wait_for_report(report_id:, interval: 5, timeout: 60)
    #   Waits for a report to complete processing by polling until the report data is available
    #   @param report_id [String, Integer] The ID of the report to wait for
    #   @param interval [Integer] Seconds to wait between checks (default: 5)
    #   @param timeout [Integer] Maximum seconds to wait before timing out (default: 60)
    #   @return [Missive::Object] The completed report with analytics data
    #   @raise [Timeout::Error] If the report doesn't complete within the timeout period
    #   @example
    #     client.analytics.wait_for_report(report_id: 'abc123', interval: 2, timeout: 120)
    class Analytics
      CREATE_REPORT = "/analytics/reports"
      GET_REPORT = "/analytics/reports/%<report_id>s"

      def initialize(client)
        @client = client
      end

      def create_report(organization:, start_time:, end_time:, **params)
        raise ArgumentError, "organization is required" if organization.nil? || organization.empty?
        raise ArgumentError, "start_time is required" if start_time.nil?
        raise ArgumentError, "end_time is required" if end_time.nil?

        payload = {
          reports: {
            organization: organization,
            start: start_time,
            end: end_time
          }.merge(params)
        }

        ActiveSupport::Notifications.instrument("missive.analytics.create_report") do
          parsed_response = @client.connection.request(:post, CREATE_REPORT, body: payload)
          # Flatten the nested reports structure for easier access
          if parsed_response.is_a?(Hash) && parsed_response[:reports]
            Missive::Object.new(parsed_response[:reports], @client)
          else
            Missive::Object.new(parsed_response, @client)
          end
        end
      end

      def get_report(report_id:)
        raise ArgumentError, "report_id is required" if report_id.nil?

        path = format(GET_REPORT, report_id: report_id)

        ActiveSupport::Notifications.instrument("missive.analytics.get_report") do
          parsed_response = @client.connection.request(:get, path)
          # Flatten the nested reports structure for easier access
          if parsed_response.is_a?(Hash) && parsed_response[:reports]
            Missive::Object.new(parsed_response[:reports], @client)
          else
            Missive::Object.new(parsed_response, @client)
          end
        end
      end

      def wait_for_report(report_id:, interval: 5, timeout: 60)
        raise ArgumentError, "report_id is required" if report_id.nil?

        start_time = Time.now
        iterations = 0

        ActiveSupport::Notifications.instrument("missive.analytics.wait_for_report") do |payload|
          loop do
            begin
              report = get_report(report_id: report_id)
              iterations += 1
              # If we successfully got the report data, it's done
              break report
            rescue Missive::NotFoundError
              # Report not ready yet, continue waiting
              iterations += 1
            end

            raise Timeout::Error, "Report did not complete within #{timeout} seconds" if Time.now - start_time > timeout

            wait_interval(interval)
          end.tap do |_result|
            payload[:iterations] = iterations
          end
        end
      end

      private

      def wait_interval(seconds)
        sleep(seconds)
      end
    end
  end
end
