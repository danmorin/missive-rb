# frozen_string_literal: true

RSpec.describe Missive::Resources::Tasks do
  let(:client) { double("Client") }
  let(:connection) { double("Connection") }
  subject { described_class.new(client) }

  before do
    allow(client).to receive(:connection).and_return(connection)
  end

  describe "#initialize" do
    it "sets the client" do
      expect(subject.client).to eq(client)
    end
  end

  describe "#create" do
    let(:title) { "Test task" }
    let(:team_id) { "team-123" }
    let(:task_response) { { tasks: { id: "task-123", title: title, state: "todo" } } }

    context "with instrumentation" do
      it "instruments the create request" do
        notifications = []
        ActiveSupport::Notifications.subscribe("missive.tasks.create") do |_name, _start, _finish, _id, payload|
          notifications << payload
        end

        expect(connection).to receive(:request).with(
          :post,
          "/tasks",
          body: { tasks: { title: title, state: "todo", team: team_id } }
        ).and_return(task_response)

        result = subject.create(title: title, team: team_id)
        expect(notifications).not_to be_empty
        expect(notifications.last[:body][:tasks][:title]).to eq(title)
        expect(result).to be_a(Missive::Object)
      end
    end

    context "with valid standalone task parameters" do
      it "creates a task assigned to a team" do
        expect(connection).to receive(:request).with(
          :post,
          "/tasks",
          body: {
            tasks: {
              title: title,
              state: "todo",
              team: team_id
            }
          }
        ).and_return(task_response)

        result = subject.create(title: title, team: team_id)

        expect(result).to be_a(Missive::Object)
        expect(result.id).to eq("task-123")
        expect(result.title).to eq(title)
      end

      it "creates a task assigned to users" do
        assignees = %w[user-1 user-2]
        expect(connection).to receive(:request).with(
          :post,
          "/tasks",
          body: {
            tasks: {
              title: title,
              state: "todo",
              assignees: assignees
            }
          }
        ).and_return(task_response)

        result = subject.create(title: title, assignees: assignees)

        expect(result).to be_a(Missive::Object)
      end

      it "creates a task with organization" do
        org_id = "org-123"
        expect(connection).to receive(:request).with(
          :post,
          "/tasks",
          body: {
            tasks: {
              title: title,
              state: "todo",
              organization: org_id,
              team: team_id
            }
          }
        ).and_return(task_response)

        result = subject.create(title: title, organization: org_id, team: team_id)

        expect(result).to be_a(Missive::Object)
      end
    end

    context "with valid subtask parameters" do
      it "creates a subtask linked to a conversation" do
        conversation_id = "conv-123"
        expect(connection).to receive(:request).with(
          :post,
          "/tasks",
          body: {
            tasks: {
              title: title,
              state: "todo",
              subtask: true,
              conversation: conversation_id
            }
          }
        ).and_return(task_response)

        result = subject.create(title: title, subtask: true, conversation: conversation_id)

        expect(result).to be_a(Missive::Object)
      end

      it "creates a subtask with references" do
        references = %w[ref-1 ref-2]
        expect(connection).to receive(:request).with(
          :post,
          "/tasks",
          body: {
            tasks: {
              title: title,
              state: "todo",
              subtask: true,
              references: references
            }
          }
        ).and_return(task_response)

        result = subject.create(title: title, subtask: true, references: references)

        expect(result).to be_a(Missive::Object)
      end
    end

    context "with additional attributes" do
      it "includes description and due_at" do
        description = "Task description"
        due_at = "2024-12-31T23:59:59Z"

        expect(connection).to receive(:request).with(
          :post,
          "/tasks",
          body: {
            tasks: {
              title: title,
              state: "todo",
              team: team_id,
              description: description,
              due_at: due_at
            }
          }
        ).and_return(task_response)

        result = subject.create(
          title: title,
          team: team_id,
          description: description,
          due_at: due_at
        )

        expect(result).to be_a(Missive::Object)
      end
    end

    context "with validation errors" do
      it "raises ArgumentError for blank title" do
        expect do
          subject.create(title: "", team: team_id)
        end.to raise_error(ArgumentError, "title cannot be blank")

        expect do
          subject.create(title: nil, team: team_id)
        end.to raise_error(ArgumentError, "title cannot be blank")

        expect do
          subject.create(title: "   ", team: team_id)
        end.to raise_error(ArgumentError, "title cannot be blank")
      end

      it "raises ArgumentError for title too long" do
        long_title = "a" * 1001
        expect do
          subject.create(title: long_title, team: team_id)
        end.to raise_error(ArgumentError, "title cannot exceed 1000 characters")
      end

      it "raises ArgumentError for invalid state" do
        expect do
          subject.create(title: title, team: team_id, state: "invalid")
        end.to raise_error(ArgumentError, "state must be one of: todo, done")
      end

      it "raises ArgumentError for standalone task without team or assignees" do
        expect do
          subject.create(title: title)
        end.to raise_error(ArgumentError, "standalone tasks require either 'team' or 'assignees'")
      end

      it "raises ArgumentError for subtask without conversation or references" do
        expect do
          subject.create(title: title, subtask: true)
        end.to raise_error(ArgumentError, "subtasks require either 'conversation' or 'references'")
      end

      it "accepts subtask with string key parameters" do
        expect(connection).to receive(:request).and_return(task_response)

        # Test that string keys work for validation
        result = subject.create(title: title, "subtask" => true, "conversation" => "conv-123")
        expect(result).to be_a(Missive::Object)
      end

      it "accepts standalone task with string key parameters" do
        expect(connection).to receive(:request).and_return(task_response)

        # Test that string keys work for validation
        result = subject.create(title: title, "team" => team_id)
        expect(result).to be_a(Missive::Object)
      end

      it "raises error for standalone task with empty assignees array" do
        expect do
          subject.create(title: title, assignees: [])
        end.to raise_error(ArgumentError, "standalone tasks require either 'team' or 'assignees'")
      end
    end

    it "handles server errors" do
      expect(connection).to receive(:request).and_return({ tasks: nil })

      expect do
        subject.create(title: title, team: team_id)
      end.to raise_error(Missive::ServerError, "Task creation failed")
    end
  end

  describe "#update" do
    let(:task_id) { "task-123" }
    let(:update_response) { { tasks: { id: task_id, title: "Updated title", state: "done" } } }

    context "with instrumentation" do
      it "instruments the update request" do
        notifications = []
        ActiveSupport::Notifications.subscribe("missive.tasks.update") do |_name, _start, _finish, _id, payload|
          notifications << payload
        end

        expect(connection).to receive(:request).with(
          :patch,
          "/tasks/task-123",
          body: { tasks: { title: "Updated title" } }
        ).and_return(update_response)

        result = subject.update(id: task_id, title: "Updated title")
        expect(notifications).not_to be_empty
        expect(notifications.last[:id]).to eq(task_id)
        expect(result).to be_a(Missive::Object)
      end
    end

    context "with valid parameters" do
      it "updates task title" do
        new_title = "Updated title"
        expect(connection).to receive(:request).with(
          :patch,
          "/tasks/task-123",
          body: { tasks: { title: new_title } }
        ).and_return(update_response)

        result = subject.update(id: task_id, title: new_title)

        expect(result).to be_a(Missive::Object)
        expect(result.id).to eq(task_id)
      end

      it "updates task state" do
        expect(connection).to receive(:request).with(
          :patch,
          "/tasks/task-123",
          body: { tasks: { state: "done" } }
        ).and_return(update_response)

        result = subject.update(id: task_id, state: "done")

        expect(result).to be_a(Missive::Object)
      end

      it "updates multiple fields" do
        attrs = {
          title: "New title",
          description: "New description",
          state: "done"
        }

        expect(connection).to receive(:request).with(
          :patch,
          "/tasks/task-123",
          body: { tasks: attrs }
        ).and_return(update_response)

        result = subject.update(id: task_id, **attrs)

        expect(result).to be_a(Missive::Object)
      end

      it "filters out non-allowed fields" do
        expect(connection).to receive(:request).with(
          :patch,
          "/tasks/task-123",
          body: { tasks: { title: "Valid title" } }
        ).and_return(update_response)

        result = subject.update(
          id: task_id,
          title: "Valid title",
          invalid_field: "should be ignored"
        )

        expect(result).to be_a(Missive::Object)
      end
    end

    context "with validation errors" do
      it "raises ArgumentError for blank id" do
        expect do
          subject.update(id: "", title: "New title")
        end.to raise_error(ArgumentError, "id cannot be blank")

        expect do
          subject.update(id: nil, title: "New title")
        end.to raise_error(ArgumentError, "id cannot be blank")

        expect do
          subject.update(id: "   ", title: "New title")
        end.to raise_error(ArgumentError, "id cannot be blank")
      end

      it "raises ArgumentError for no attributes" do
        expect do
          subject.update(id: task_id)
        end.to raise_error(ArgumentError, "no attributes provided for update")
      end

      it "raises ArgumentError for no valid attributes" do
        expect do
          subject.update(id: task_id, invalid_field: "value")
        end.to raise_error(ArgumentError, "no valid attributes provided for update")
      end

      it "raises ArgumentError for invalid state" do
        expect do
          subject.update(id: task_id, state: "invalid")
        end.to raise_error(ArgumentError, "state must be one of: todo, done")
      end

      it "handles string key state validation" do
        expect do
          subject.update(id: task_id, "state" => "invalid")
        end.to raise_error(ArgumentError, "state must be one of: todo, done")
      end

      it "converts string key state to symbol" do
        expect(connection).to receive(:request).with(
          :patch,
          "/tasks/task-123",
          body: { tasks: { state: "done" } }
        ).and_return(update_response)

        result = subject.update(id: task_id, "state" => "done")
        expect(result).to be_a(Missive::Object)
      end

      it "handles string key state to symbol conversion with filtering" do
        attrs = { "state" => "done", "title" => "New Title" }
        expect(connection).to receive(:request).with(
          :patch,
          "/tasks/task-123",
          body: { tasks: { state: "done", "title" => "New Title" } }
        ).and_return(update_response)

        result = subject.update(id: task_id, **attrs)
        expect(result).to be_a(Missive::Object)
      end

      it "validates title length for string keys" do
        long_title = "a" * 1001
        expect do
          subject.update(id: task_id, "title" => long_title)
        end.to raise_error(ArgumentError, "title cannot exceed 1000 characters")
      end

      it "raises ArgumentError for title too long" do
        long_title = "a" * 1001
        expect do
          subject.update(id: task_id, title: long_title)
        end.to raise_error(ArgumentError, "title cannot exceed 1000 characters")
      end
    end

    it "handles server errors" do
      expect(connection).to receive(:request).and_return({ tasks: nil })

      expect do
        subject.update(id: task_id, title: "New title")
      end.to raise_error(Missive::ServerError, "Task update failed")
    end
  end
end
