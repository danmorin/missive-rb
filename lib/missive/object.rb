# frozen_string_literal: true

require "json"

module Missive
  class Object
    attr_reader :attributes, :client

    def initialize(attributes, client = nil)
      @attributes = attributes.is_a?(Hash) ? attributes : {}
      @client = client
    end

    def to_h
      deep_dup(attributes)
    end

    def dig(*keys)
      attributes.dig(*keys)
    end

    def [](key)
      attributes[key.to_sym]
    end

    def reload!
      return self unless self_link

      parsed_response = client.connection.request(:get, self_link)
      @attributes = parsed_response

      self
    end

    def ==(other)
      return false unless other.is_a?(self.class)
      return false unless attributes["id"] && other.attributes["id"]

      attributes["id"] == other.attributes["id"]
    end

    def respond_to_missing?(method_name, include_private = false)
      attribute_key = method_name.to_s

      return true if attributes.key?(attribute_key)

      # Check if any camelCase keys would convert to this snake_case method name
      camel_case_keys = attributes.keys.select { |k| underscore(k) == attribute_key }
      return true if camel_case_keys.any?

      super
    end

    def method_missing(method_name, *args, &)
      attribute_key = method_name.to_s

      if attributes.key?(attribute_key)
        attributes[attribute_key]
      else
        # Try to find a camelCase version that would convert to this snake_case method name
        camel_case_keys = attributes.keys.select { |k| underscore(k) == attribute_key }
        if camel_case_keys.any?
          attributes[camel_case_keys.first]
        else
          super
        end
      end
    end

    private

    def self_link
      dig("_links", "self")
    end

    def deep_dup(obj)
      case obj
      when Hash
        obj.transform_values { |value| deep_dup(value) }
      when Array
        obj.map { |item| deep_dup(item) }
      else
        begin
          obj.dup
        rescue StandardError
          obj
        end
      end
    end

    def underscore(camel_cased_word)
      camel_cased_word.to_s.gsub("::", "/")
                      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                      .tr("-", "_")
                      .downcase
    end
  end
end
