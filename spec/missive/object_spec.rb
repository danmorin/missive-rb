# frozen_string_literal: true

require "spec_helper"

RSpec.describe Missive::Object do
  let(:client) { instance_double("Missive::Client") }
  let(:connection) { instance_double("Missive::Connection") }
  let(:attributes) { { "id" => 123, "name" => "Test Object", "first_name" => "John" } }

  before do
    allow(client).to receive(:connection).and_return(connection)
  end

  describe "#initialize" do
    it "stores attributes and client" do
      object = described_class.new(attributes, client)
      expect(object.attributes).to eq(attributes)
      expect(object.client).to eq(client)
    end

    it "handles non-hash attributes" do
      object = described_class.new("invalid", client)
      expect(object.attributes).to eq({})
    end

    it "works without client" do
      object = described_class.new(attributes)
      expect(object.client).to be_nil
    end
  end

  describe "#to_h" do
    it "returns deep duplicate of attributes" do
      nested_attributes = { "id" => 123, "meta" => { "created_at" => "2023-01-01" } }
      object = described_class.new(nested_attributes, client)
      result = object.to_h

      expect(result).to eq(nested_attributes)
      expect(result).not_to equal(nested_attributes)
      expect(result["meta"]).not_to equal(nested_attributes["meta"])
    end

    it "handles arrays and complex nested structures" do
      complex_attributes = {
        "id" => 123,
        "tags" => %w[tag1 tag2],
        "metadata" => {
          "settings" => { "enabled" => true },
          "history" => [{ "date" => "2023-01-01" }]
        }
      }
      object = described_class.new(complex_attributes, client)
      result = object.to_h

      expect(result).to eq(complex_attributes)
      expect(result["tags"]).not_to equal(complex_attributes["tags"])
      expect(result["metadata"]["history"]).not_to equal(complex_attributes["metadata"]["history"])
    end

    it "handles objects that cannot be duped" do
      # Test with simple numbers/booleans that can't be duped
      attributes_with_undupable = { "id" => 123, "enabled" => true, "score" => 99.5 }
      object = described_class.new(attributes_with_undupable, client)
      result = object.to_h

      expect(result["id"]).to eq(123)
      expect(result["enabled"]).to eq(true)
      expect(result["score"]).to eq(99.5)
    end

    it "handles objects that raise errors when duped" do
      # Create an object that raises an error when dup is called
      error_object = Object.new
      allow(error_object).to receive(:dup).and_raise(StandardError, "Cannot dup")
      
      attributes_with_error_object = { "id" => 123, "special" => error_object }
      object = described_class.new(attributes_with_error_object, client)
      result = object.to_h

      expect(result["id"]).to eq(123)
      expect(result["special"]).to equal(error_object) # Should be the same object due to rescue
    end
  end

  describe "#dig" do
    it "forwards to attributes.dig" do
      nested_attributes = { "meta" => { "created_at" => "2023-01-01" } }
      object = described_class.new(nested_attributes, client)

      expect(object.dig("meta", "created_at")).to eq("2023-01-01")
      expect(object.dig("meta", "nonexistent")).to be_nil
      expect(object.dig("nonexistent")).to be_nil
    end
  end

  describe "#reload!" do
    context "when self link is present" do
      let(:attributes_with_link) do
        {
          "id" => 123,
          "name" => "Test Object",
          "_links" => { "self" => "/objects/123" }
        }
      end

      it "issues GET request and updates attributes" do
        updated_attributes = { "id" => 123, "name" => "Updated Object" }

        allow(connection).to receive(:request).with(:get, "/objects/123").and_return(updated_attributes)

        object = described_class.new(attributes_with_link, client)
        result = object.reload!

        expect(connection).to have_received(:request).with(:get, "/objects/123")
        expect(object.attributes).to eq(updated_attributes)
        expect(result).to eq(object)
      end
    end

    context "when self link is not present" do
      it "returns self without making request" do
        allow(connection).to receive(:request)
        object = described_class.new(attributes, client)
        result = object.reload!

        expect(connection).not_to have_received(:request)
        expect(result).to eq(object)
      end
    end
  end

  describe "#==" do
    it "returns true when class and id match" do
      object1 = described_class.new({ "id" => 123 }, client)
      object2 = described_class.new({ "id" => 123 }, client)

      expect(object1).to eq(object2)
    end

    it "returns false when ids do not match" do
      object1 = described_class.new({ "id" => 123 }, client)
      object2 = described_class.new({ "id" => 456 }, client)

      expect(object1).not_to eq(object2)
    end

    it "returns false when either object lacks id" do
      object1 = described_class.new({ "id" => 123 }, client)
      object2 = described_class.new({ "name" => "No ID" }, client)

      expect(object1).not_to eq(object2)
    end

    it "returns false when comparing to different class" do
      object = described_class.new({ "id" => 123 }, client)

      expect(object).not_to eq("string")
    end
  end

  describe "method_missing and respond_to_missing?" do
    let(:object) { described_class.new(attributes, client) }

    it "provides access to hash keys as methods" do
      expect(object.id).to eq(123)
      expect(object.name).to eq("Test Object")
    end

    it "provides access to underscored keys" do
      expect(object.first_name).to eq("John")
    end

    it "responds to method names that match keys" do
      expect(object).to respond_to(:id)
      expect(object).to respond_to(:name)
      expect(object).to respond_to(:first_name)
    end

    it "does not respond to non-existent keys" do
      expect(object).not_to respond_to(:nonexistent)
    end

    it "raises NoMethodError for non-existent methods" do
      expect { object.nonexistent }.to raise_error(NoMethodError)
    end

    it "never mutates underlying hash" do
      original_attributes = attributes.dup
      object.id
      object.name

      expect(object.attributes).to eq(original_attributes)
    end

    it "handles snake_case conversion for missing keys" do
      camel_attributes = { "first_name" => "John", "last_name" => "Doe" }
      object = described_class.new(camel_attributes, client)

      expect(object.first_name).to eq("John")
      expect(object.last_name).to eq("Doe")
    end

    it "handles actual camelCase to snake_case conversion" do
      camel_attributes = { "firstName" => "John" }
      object = described_class.new(camel_attributes, client)

      # This should access via the underscore path
      expect(object.first_name).to eq("John")
      expect(object).to respond_to(:first_name)
    end

    it "handles complex underscore conversions" do
      # Test edge cases in the underscore method  
      camel_attributes = { 
        "XMLParser" => "value1", 
        "HTTPSConnection" => "value2",
        "APIKey" => "value3",
        "some-dashed-key" => "value4",
        "mixedCaseWithLowerStart" => "value6"
      }
      object = described_class.new(camel_attributes, client)

      # Test the underscore conversion for complex cases
      expect(object.xml_parser).to eq("value1")
      expect(object.https_connection).to eq("value2") 
      expect(object.api_key).to eq("value3")
      expect(object.some_dashed_key).to eq("value4")
      expect(object.mixed_case_with_lower_start).to eq("value6")
    end
  end
end
