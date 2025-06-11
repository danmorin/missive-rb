# frozen_string_literal: true

require "logger"
require "active_support/notifications"

module Missive
  class Configuration
    attr_accessor :logger, :instrumenter, :token_lookup, :base_url, :soft_limit_threshold

    def initialize
      @logger = Logger.new($stdout).tap { |l| l.level = Logger::INFO }
      @instrumenter = ActiveSupport::Notifications
      @token_lookup = ->(_email) {}
      @base_url = Missive::Constants::BASE_URL
      @soft_limit_threshold = 30
    end

    def freeze
      instance_variables.each do |var|
        instance_variable_get(var).freeze
      end
      super
    end
  end
end
