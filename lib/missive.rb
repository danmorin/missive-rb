# frozen_string_literal: true

require "missive/version"
require "missive/configuration"
require "missive/client"
require "missive/paginator"
require "missive/object"
require "missive/signature"
require "missive/resources/contacts"
require "missive/resources/contact_books"
require "missive/resources/contact_groups"
require "missive/resources/drafts"
require "missive/resources/posts"
require "missive/resources/shared_labels"
require "missive/resources/organizations"
require "missive/resources/responses"
require "missive/resources/tasks"
require "missive/resources/teams"
require "missive/resources/users"
require "missive/resources/hooks"
require "missive/webhook_server"

# Optional CLI - only load if not in test mode to avoid execution during testing
unless defined?(RSpec)
  begin
    require "thor"
    require "missive/cli" if defined?(Thor)
  rescue LoadError
    # Thor not available, skip CLI
  end
end

# Optional Rails integration
begin
  require "rails"
  require "missive/railtie" if defined?(Rails::Railtie)
rescue LoadError
  # Rails not available, skip railtie
end

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
