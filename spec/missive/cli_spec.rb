# frozen_string_literal: true

require "missive/cli"

RSpec.describe Missive::CLI do
  let(:api_token) { "test-token" }
  let(:config_content) { { "api_token" => api_token }.to_yaml }
  let(:config_file) { File.expand_path("~/.missive.yml") }

  before do
    # Mock file system interactions
    allow(File).to receive(:exist?).with(config_file).and_return(true)
    allow(YAML).to receive(:load_file).with(config_file).and_return({ "api_token" => api_token })

    # Mock Missive::Client
    @client_double = double("Missive::Client")
    allow(Missive::Client).to receive(:new).with(api_token: api_token).and_return(@client_double)
  end

  describe "teams list" do
    let(:teams_resource) { double("Teams") }
    let(:teams_data) do
      [
        double("Team", to_h: { id: "team-1", name: "Team One" }),
        double("Team", to_h: { id: "team-2", name: "Team Two" })
      ]
    end

    before do
      allow(@client_double).to receive(:teams).and_return(teams_resource)
      allow(teams_data).to receive(:compact).and_return(teams_data)
    end

    it "lists teams with default parameters" do
      expect(teams_resource).to receive(:list).with(
        limit: 10,
        organization: nil
      ).and_return(teams_data)

      expect { described_class.start(%w[teams list]) }.to output(
        /"id": "team-1".*"name": "Team One".*"id": "team-2".*"name": "Team Two"/m
      ).to_stdout
    end

    it "lists teams with custom limit" do
      expect(teams_resource).to receive(:list).with(
        limit: 5,
        organization: nil
      ).and_return(teams_data)

      expect { described_class.start(["teams", "list", "--limit", "5"]) }.to output(
        /"id": "team-1".*"name": "Team One"/m
      ).to_stdout
    end

    it "lists teams with organization filter" do
      org_id = "org-123"
      expect(teams_resource).to receive(:list).with(
        limit: 10,
        organization: org_id
      ).and_return(teams_data)

      expect { described_class.start(["teams", "list", "--organization", org_id]) }.to output(
        /"id": "team-1".*"name": "Team One"/m
      ).to_stdout
    end

    it "handles empty teams list" do
      allow(teams_data).to receive(:compact).and_return([])
      expect(teams_resource).to receive(:list).and_return([])

      expect { described_class.start(%w[teams list]) }.to output(
        "No teams found\n"
      ).to_stdout
    end

    it "handles API errors gracefully" do
      expect(teams_resource).to receive(:list).and_raise(StandardError, "API Error")

      expect { described_class.start(%w[teams list]) }.to output(
        "Error: API Error\n"
      ).to_stdout.and raise_error(SystemExit)
    end
  end

  describe "tasks create" do
    let(:tasks_resource) { double("Tasks") }
    let(:created_task) { double("Task", id: "task-123") }

    before do
      allow(@client_double).to receive(:tasks).and_return(tasks_resource)
    end

    it "creates a task with required parameters" do
      expect(tasks_resource).to receive(:create).with(
        title: "Test task",
        team: "team-123",
        state: "todo"
      ).and_return(created_task)

      expect do
        described_class.start([
                                "tasks", "create",
                                "--title", "Test task",
                                "--team", "team-123"
                              ])
      end.to output("task-123\n").to_stdout
    end

    it "creates a task with all optional parameters" do
      expect(tasks_resource).to receive(:create).with(
        title: "Test task",
        team: "team-123",
        organization: "org-123",
        state: "done",
        description: "Task description",
        assignees: %w[user-1 user-2],
        due_at: "2024-12-31T23:59:59Z"
      ).and_return(created_task)

      expect do
        described_class.start([
                                "tasks", "create",
                                "--title", "Test task",
                                "--team", "team-123",
                                "--organization", "org-123",
                                "--state", "done",
                                "--description", "Task description",
                                "--assignees", "user-1", "user-2",
                                "--due-at", "2024-12-31T23:59:59Z"
                              ])
      end.to output("task-123\n").to_stdout
    end

    it "handles missing title error" do
      expect do
        described_class.start(["tasks", "create", "--team", "team-123"])
      end.to raise_error(SystemExit)
    end

    it "handles API errors gracefully" do
      expect(tasks_resource).to receive(:create).and_raise(StandardError, "Validation failed")

      expect do
        described_class.start([
                                "tasks", "create",
                                "--title", "Test task",
                                "--team", "team-123"
                              ])
      end.to output("Error: Validation failed\n").to_stdout.and raise_error(SystemExit)
    end
  end

  describe "hooks delete" do
    let(:hooks_resource) { double("Hooks") }

    before do
      allow(@client_double).to receive(:hooks).and_return(hooks_resource)
    end

    it "deletes a hook" do
      hook_id = "hook-123"
      expect(hooks_resource).to receive(:delete).with(id: hook_id).and_return(true)

      expect do
        described_class.start(["hooks", "delete", hook_id])
      end.to output("deleted\n").to_stdout
    end

    it "handles API errors gracefully" do
      hook_id = "hook-123"
      expect(hooks_resource).to receive(:delete).and_raise(StandardError, "Hook not found")

      expect do
        described_class.start(["hooks", "delete", hook_id])
      end.to output("Error: Hook not found\n").to_stdout.and raise_error(SystemExit)
    end
  end

  describe "configuration loading" do
    context "when config file exists" do
      it "loads token from config file" do
        expect(Missive::Client).to receive(:new).with(api_token: api_token)
        described_class.new.send(:client)
      end
    end

    context "when config file doesn't exist" do
      before do
        allow(File).to receive(:exist?).with(config_file).and_return(false)
        allow(ENV).to receive(:fetch).with("MISSIVE_API_TOKEN", nil).and_return("env-token")
      end

      it "loads token from environment" do
        expect(Missive::Client).to receive(:new).with(api_token: "env-token")
        described_class.new.send(:client)
      end
    end

    context "when no token is available" do
      before do
        allow(File).to receive(:exist?).with(config_file).and_return(false)
        allow(ENV).to receive(:fetch).with("MISSIVE_API_TOKEN", nil).and_return(nil)
      end

      it "exits with error message" do
        expect do
          described_class.new.send(:client)
        end.to output(/No API token found/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "when config file has errors" do
      before do
        allow(YAML).to receive(:load_file).and_raise(StandardError, "Invalid YAML")
      end

      it "handles config loading errors" do
        expect do
          described_class.new.send(:load_config)
        end.to output(/Error loading config/).to_stdout
      end
    end
  end

  describe "contacts sync" do
    let(:contacts_resource) { double("Contacts") }
    let(:contact_data) { double("Contact", to_h: { id: "contact-1", name: "John Doe" }) }

    before do
      allow(@client_double).to receive(:contacts).and_return(contacts_resource)
    end

    it "syncs contacts with default parameters" do
      expect(contacts_resource).to receive(:each_item).with(
        limit: 50,
        modified_since: nil
      ).and_yield(contact_data)

      expect { described_class.start(%w[contacts sync]) }.to output(
        /{"id":"contact-1","name":"John Doe"}/
      ).to_stdout
    end

    it "syncs contacts with since parameter" do
      # Allow for timezone differences - just check that it's a reasonable timestamp
      expect(contacts_resource).to receive(:each_item) do |params|
        expect(params[:limit]).to eq(50)
        expect(params[:modified_since]).to be_a(Integer)
        expect(params[:modified_since]).to be_between(1_609_459_200, 1_609_545_600) # 2021-01-01 range
      end.and_yield(contact_data)

      expect { described_class.start(%w[contacts sync --since 2021-01-01]) }.to output(
        /{"id":"contact-1","name":"John Doe"}/
      ).to_stdout
    end

    it "handles invalid date format" do
      expect do
        described_class.start(%w[contacts sync --since invalid-date])
      end.to output(/Invalid date format/).to_stdout.and raise_error(SystemExit)
    end

    it "handles API errors gracefully" do
      allow(contacts_resource).to receive(:each_item).and_raise(StandardError, "API Error")

      expect do
        described_class.start(%w[contacts sync])
      end.to output(/Error: API Error/).to_stdout.and raise_error(SystemExit)
    end
  end

  describe "conversations export" do
    let(:conversations_resource) { double("Conversations") }
    let(:conversation_data) { double("Conversation", to_h: { id: "conv-1", subject: "Test" }) }
    let(:message_data) { double("Message", to_h: { id: "msg-1", body: "Hello" }) }
    let(:comment_data) { double("Comment", to_h: { id: "comment-1", text: "Note" }) }
    let(:temp_file) { "/tmp/test_export.json" }

    before do
      allow(@client_double).to receive(:conversations).and_return(conversations_resource)
      allow(File).to receive(:write)
    end

    it "exports conversation with messages and comments" do
      expect(conversations_resource).to receive(:get).with("conv-1").and_return(conversation_data)
      expect(conversations_resource).to receive(:each_message).with("conv-1").and_yield(message_data)
      expect(conversations_resource).to receive(:each_comment).with("conv-1").and_yield(comment_data)

      expected_data = {
        conversation: { id: "conv-1", subject: "Test" },
        messages: [{ id: "msg-1", body: "Hello" }],
        comments: [{ id: "comment-1", text: "Note" }]
      }

      expect(File).to receive(:write).with(temp_file, JSON.pretty_generate(expected_data))

      expect do
        described_class.start(["conversations", "export", "--id", "conv-1", "--file", temp_file])
      end.to output(/Exported conversation conv-1 to #{Regexp.escape(temp_file)}/).to_stdout
    end

    it "handles API errors gracefully" do
      allow(conversations_resource).to receive(:get).and_raise(StandardError, "Not found")

      expect do
        described_class.start(["conversations", "export", "--id", "conv-1", "--file", temp_file])
      end.to output(/Error: Not found/).to_stdout.and raise_error(SystemExit)
    end
  end

  describe "analytics report" do
    let(:analytics_resource) { double("Analytics") }
    let(:report_data) { double("Report", id: "report-1", data: double("Data", url: "https://example.com/report.csv")) }

    before do
      allow(@client_double).to receive(:analytics).and_return(analytics_resource)
    end

    it "creates report without waiting" do
      expect(analytics_resource).to receive(:create_report).with(
        reports: { type: "email_volume" }
      ).and_return(report_data)

      expect do
        described_class.start(["analytics", "report", "--type", "email_volume"])
      end.to output(%r{https://example\.com/report\.csv}).to_stdout
    end

    it "creates report and waits for completion" do
      completed_report = double("CompletedReport", data: double("Data", url: "https://example.com/completed.csv"))

      expect(analytics_resource).to receive(:create_report).with(
        reports: { type: "email_volume" }
      ).and_return(report_data)

      expect(analytics_resource).to receive(:wait_for_report).with(
        "report-1",
        timeout: 300
      ).and_return(completed_report)

      expect do
        described_class.start(["analytics", "report", "--type", "email_volume", "--wait"])
      end.to output(%r{https://example\.com/completed\.csv}).to_stdout
    end

    it "handles API errors gracefully" do
      allow(analytics_resource).to receive(:create_report).and_raise(StandardError, "Invalid type")

      expect do
        described_class.start(["analytics", "report", "--type", "invalid_type"])
      end.to output(/Error: Invalid type/).to_stdout.and raise_error(SystemExit)
    end
  end

  describe "--token flag support" do
    let(:token_from_flag) { "flag-token" }

    it "uses token from --token flag over config file" do
      expect(Missive::Client).to receive(:new).with(api_token: token_from_flag)

      cli = described_class.new([], { token: token_from_flag })
      cli.send(:client)
    end

    it "uses token from --token flag over environment" do
      allow(File).to receive(:exist?).with(config_file).and_return(false)
      allow(ENV).to receive(:fetch).with("MISSIVE_API_TOKEN", nil).and_return("env-token")

      expect(Missive::Client).to receive(:new).with(api_token: token_from_flag)

      cli = described_class.new([], { token: token_from_flag })
      cli.send(:client)
    end
  end
end
