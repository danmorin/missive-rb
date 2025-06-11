# frozen_string_literal: true

module Missive
  module Middleware
    class Instrumentation < Faraday::Middleware
      def call(env)
        start_time = Time.now

        Missive.configuration.instrumenter.instrument("missive.request", {
                                                        method: env.method.to_s.upcase,
                                                        path: env.url.path,
                                                        url: env.url.to_s
                                                      }) do
          response = @app.call(env)

          Missive.configuration.instrumenter.instrument("missive.response", {
                                                          method: env.method.to_s.upcase,
                                                          path: env.url.path,
                                                          url: env.url.to_s,
                                                          status: response.status,
                                                          duration: Time.now - start_time
                                                        })

          response
        end
      end
    end
  end
end
