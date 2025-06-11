# frozen_string_literal: true

require "missive/configuration"
require "missive/client"
require "missive/paginator"
require "missive/object"
require "missive/signature"

module Missive
  class << self
    def configure
      yield(configuration) if block_given?
      configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset_configuration!
      @configuration = nil
    end
  end
end
