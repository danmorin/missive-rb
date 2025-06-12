# frozen_string_literal: true

require "missive/version"
require "missive/constants"
require "missive/connection"
require "missive/error"
require "missive/resources/analytics"
require "missive/resources/conversations"
require "missive/resources/messages"

module Missive
  # @!method drafts
  #   Access the Drafts resource
  #   @return [Missive::Resources::Drafts] Drafts resource instance
  #   @example
  #     client.drafts.create(body: "Hello", to_fields: [{address: "user@example.com"}], from_field: {address: "me@example.com"})
  #     client.drafts.send_message(draft_id: "draft-123")
  #
  # @!method posts
  #   Access the Posts resource
  #   @return [Missive::Resources::Posts] Posts resource instance
  #   @example
  #     client.posts.create(text: "Hello from webhook", conversation: "conv-123")
  #     client.posts.delete(id: "post-123")
  #
  # @!method shared_labels
  #   Access the SharedLabels resource
  #   @return [Missive::Resources::SharedLabels] SharedLabels resource instance
  #   @example
  #     client.shared_labels.create(labels: [{name: "Important", organization: "org-123", color: "#ff0000"}])
  #     client.shared_labels.list(organization: "org-123")
  #
  # @!method organizations
  #   Access the Organizations resource
  #   @return [Missive::Resources::Organizations] Organizations resource instance
  #   @example
  #     client.organizations.list(limit: 50)
  #     client.organizations.each_item { |org| puts org.name }
  #
  # @!method responses
  #   Access the Responses resource
  #   @return [Missive::Resources::Responses] Responses resource instance
  #   @example
  #     client.responses.list(organization: "org-123")
  #     client.responses.get(id: "resp-123")
  class Client
    attr_reader :config, :token

    def initialize(api_token:, base_url: Missive::Constants::BASE_URL, **options)
      raise MissingTokenError, "api_token cannot be nil" if api_token.nil?

      @token = api_token
      @config = { base_url: base_url, **options }.freeze
    end

    def connection
      @connection ||= Missive::Connection.new(
        token: token,
        base_url: config[:base_url],
        timeout: config[:timeout],
        logger: config[:logger]
      )
    end

    def analytics
      @analytics ||= Missive::Resources::Analytics.new(self)
    end

    def contacts
      @contacts ||= Missive::Resources::Contacts.new(self)
    end

    def contact_books
      @contact_books ||= Missive::Resources::ContactBooks.new(self)
    end

    def contact_groups
      @contact_groups ||= Missive::Resources::ContactGroups.new(self)
    end

    def conversations
      @conversations ||= Missive::Resources::Conversations.new(self)
    end

    def messages
      @messages ||= Missive::Resources::Messages.new(self)
    end

    def drafts
      @drafts ||= Missive::Resources::Drafts.new(self)
    end

    def posts
      @posts ||= Missive::Resources::Posts.new(self)
    end

    def shared_labels
      @shared_labels ||= Missive::Resources::SharedLabels.new(self)
    end

    def organizations
      @organizations ||= Missive::Resources::Organizations.new(self)
    end

    def responses
      @responses ||= Missive::Resources::Responses.new(self)
    end
  end
end
