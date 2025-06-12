# frozen_string_literal: true

require "spec_helper"

RSpec.describe Missive::Resources::SharedLabels do
  let(:client) { Missive::Client.new(api_token: "test-token") }
  let(:shared_labels) { described_class.new(client) }
  let(:connection) { instance_double(Missive::Connection) }
  subject { shared_labels }

  before do
    allow(client).to receive(:connection).and_return(connection)
  end

  describe "#initialize" do
    it "stores the client" do
      expect(shared_labels.instance_variable_get(:@client)).to eq(client)
    end
  end

  describe "#create" do
    let(:valid_labels) do
      [
        { name: "Important", organization: "org-123", color: "#ff0000" },
        { name: "Urgent", organization: "org-123", color: "warning" }
      ]
    end

    let(:response_data) do
      [
        { "id" => "label-1", "name" => "Important", "organization" => "org-123" },
        { "id" => "label-2", "name" => "Urgent", "organization" => "org-123" }
      ]
    end

    context "successful creation" do
      it "creates two labels and returns array of correct length" do
        expected_payload = { shared_labels: valid_labels }

        expect(connection).to receive(:request).with(
          :post,
          "/shared_labels",
          body: expected_payload
        ).and_return(response_data)

        result = shared_labels.create(labels: valid_labels)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.first).to be_a(Missive::Object)
        expect(result.first.id).to eq("label-1")
      end
    end

    context "color validation" do
      it "accepts valid hex colors" do
        valid_colors = ["#fff", "#FF0000", "#12ab34"]
        allow(connection).to receive(:request).and_return(response_data)

        valid_colors.each do |color|
          labels = [{ name: "Test", organization: "org-123", color: color }]
          expect { shared_labels.create(labels: labels) }.not_to raise_error
        end
      end

      it "accepts valid color words" do
        %w[good warning danger].each do |color|
          labels = [{ name: "Test", organization: "org-123", color: color }]
          allow(connection).to receive(:request).and_return(response_data)
          expect { shared_labels.create(labels: labels) }.not_to raise_error
        end
      end

      it "raises error for invalid colors" do
        invalid_labels = [{ name: "Test", organization: "org-123", color: "invalid" }]

        expect do
          shared_labels.create(labels: invalid_labels)
        end.to raise_error(ArgumentError, /Invalid color/)
      end
    end

    context "required field validation" do
      it "raises error when name is missing" do
        labels = [{ organization: "org-123" }]

        expect do
          shared_labels.create(labels: labels)
        end.to raise_error(ArgumentError, "Each label must have a name")
      end

      it "raises error when organization is missing" do
        labels = [{ name: "Test" }]

        expect do
          shared_labels.create(labels: labels)
        end.to raise_error(ArgumentError, "Each label must have an organization")
      end
    end

    context "instrumentation" do
      it "calls the create method within instrumentation block" do
        allow(connection).to receive(:request).and_return(response_data)

        expect(connection).to receive(:request).with(:post, "/shared_labels", body: { shared_labels: valid_labels })

        shared_labels.create(labels: valid_labels)
      end
    end
  end

  describe "#update" do
    let(:labels_to_update) do
      [
        { id: "label-1", name: "Updated Important", organization: "org-123", color: "#00ff00" },
        { id: "label-2", name: "Updated Urgent", organization: "org-123", color: "danger" }
      ]
    end

    let(:response_data) do
      [
        { "id" => "label-1", "name" => "Updated Important" },
        { "id" => "label-2", "name" => "Updated Urgent" }
      ]
    end

    it "concatenates ids correctly in path" do
      expected_payload = { shared_labels: labels_to_update }

      expect(connection).to receive(:request).with(
        :patch,
        "/shared_labels/label-1,label-2",
        body: expected_payload
      ).and_return(response_data)

      shared_labels.update(labels: labels_to_update)
    end

    it "returns array of updated objects" do
      allow(connection).to receive(:request).and_return(response_data)

      result = shared_labels.update(labels: labels_to_update)

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.first).to be_a(Missive::Object)
    end

    context "instrumentation" do
      it "calls the update method within instrumentation block" do
        allow(connection).to receive(:request).and_return(response_data)

        expect(connection).to receive(:request).with(:patch, "/shared_labels/label-1,label-2",
                                                     body: { shared_labels: labels_to_update })

        shared_labels.update(labels: labels_to_update)
      end
    end
  end

  describe "#list" do
    let(:response_data) do
      {
        "shared_labels" => [
          { "id" => "label-1", "name" => "Important" },
          { "id" => "label-2", "name" => "Urgent" }
        ],
        "offset" => 0,
        "limit" => 50
      }
    end

    it "sends GET request with default parameters" do
      expect(connection).to receive(:request).with(
        :get,
        "/shared_labels",
        params: { limit: 50, offset: 0 }
      ).and_return(response_data)

      shared_labels.list
    end

    it_behaves_like "a list endpoint", "shared_labels", "/shared_labels"

    context "with organization filter" do
      it_behaves_like "a list endpoint", "shared_labels", "/shared_labels", { organization: "org-123" }
    end

    context "with organization filter" do
      it "includes organization in params" do
        expect(connection).to receive(:request).with(
          :get,
          "/shared_labels",
          params: { limit: 50, offset: 0, organization: "org-123" }
        ).and_return(response_data)

        shared_labels.list(organization: "org-123")
      end
    end
  end

  describe "#each_item" do
    it_behaves_like "a paginated list endpoint", "/shared_labels", :shared_labels

    context "with organization filter" do
      it_behaves_like "a paginated list endpoint", "/shared_labels", :shared_labels, { organization: "org-123" }
    end

    it "yields Missive::Object instances from each_item" do
      # Mock the Paginator to actually call the block
      allow(Missive::Paginator).to receive(:each_item).with(
        path: "/shared_labels",
        client: client,
        params: { limit: 50 },
        data_key: :shared_labels
      ) do |&block|
        # This will exercise the yield line in shared_labels.rb:89
        block.call({ "id" => "label-1", "name" => "Test Label" })
      end

      yielded_items = []
      shared_labels.each_item { |item| yielded_items << item }

      expect(yielded_items.length).to eq(1)
      expect(yielded_items.first).to be_a(Missive::Object)
      expect(yielded_items.first.id).to eq("label-1")
    end

    context "organization filtering" do
      it "passes organization parameter to paginator" do
        expect(Missive::Paginator).to receive(:each_item).with(
          path: "/shared_labels",
          client: client,
          params: hash_including(organization: "org-123"),
          data_key: :shared_labels
        )

        shared_labels.each_item(organization: "org-123") { |_| } # rubocop:disable Lint/EmptyBlock
      end
    end
  end
end
