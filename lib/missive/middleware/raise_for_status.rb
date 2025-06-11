# frozen_string_literal: true

module Missive
  module Middleware
    class RaiseForStatus < Faraday::Middleware
      def call(env)
        response = @app.call(env)

        if response.status >= 400
          error_class = Missive::Error.from_status(response.status, response.body)
          message = extract_error_message(response.body) || "HTTP #{response.status}"
          raise error_class, message
        end

        response
      end

      private

      def extract_error_message(body)
        return body if body.is_a?(String)
        return body[:error] if body.is_a?(Hash) && body[:error]
        return body["error"] if body.is_a?(Hash) && body["error"]

        nil
      end
    end
  end
end
