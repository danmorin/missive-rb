# frozen_string_literal: true

RSpec.shared_examples "a list endpoint" do |resource_key|
  it "sends GET request with default parameters" do
    allow(connection).to receive(:request).and_return(response)

    if defined?(required_list_params)
      result = subject.list(**required_list_params)
      expect(connection).to have_received(:request).with(
        :get,
        list_path,
        params: hash_including(required_list_params.merge(limit: 50, offset: 0))
      )
    else
      result = subject.list
      expect(connection).to have_received(:request).with(
        :get,
        list_path,
        params: hash_including(limit: 50, offset: 0)
      )
    end

    expect(result).to be_an(Array)
    expect(result.first).to be_a(Missive::Object) if result.any?
  end

  it "sends GET request with custom parameters" do
    allow(connection).to receive(:request).and_return(response)

    if defined?(required_list_params)
      subject.list(**required_list_params, limit: 100, offset: 50)
      expect(connection).to have_received(:request).with(
        :get,
        list_path,
        params: hash_including(required_list_params.merge(limit: 100, offset: 50))
      )
    else
      subject.list(limit: 100, offset: 50)
      expect(connection).to have_received(:request).with(
        :get,
        list_path,
        params: hash_including(limit: 100, offset: 50)
      )
    end
  end

  it "raises ArgumentError when limit exceeds 200" do
    args = defined?(required_list_params) ? required_list_params.merge(limit: 201) : { limit: 201 }
    expect do
      subject.list(**args)
    end.to raise_error(ArgumentError, "limit cannot exceed 200")
  end

  it "emits instrumentation event" do
    allow(connection).to receive(:request).and_return(response)
    notifications = []

    ActiveSupport::Notifications.subscribe("missive.#{resource_key}.list") do |_name, _start, _finish, _id, payload|
      notifications << payload
    end

    args = defined?(required_list_params) ? required_list_params.merge(limit: 25) : { limit: 25 }
    subject.list(**args)

    expect(notifications).not_to be_empty
    expect(notifications.first[:params]).to include(limit: 25)
  end

  it "handles empty array in response" do
    empty_response = { resource_key => [], offset: 0, limit: 50 }
    allow(connection).to receive(:request).and_return(empty_response)

    result = if defined?(required_list_params)
               subject.list(**required_list_params)
             else
               subject.list
             end

    expect(result).to be_an(Array)
    expect(result).to be_empty
  end

  it "handles missing resource key in response" do
    bad_response = { offset: 0, limit: 50 }
    allow(connection).to receive(:request).and_return(bad_response)

    result = if defined?(required_list_params)
               subject.list(**required_list_params)
             else
               subject.list
             end

    expect(result).to be_an(Array)
    expect(result).to be_empty
  end
end

RSpec.shared_examples "a paginated list endpoint" do
  it "uses default limit of 50 when not provided" do
    empty_response = { data_key => [], offset: 0, limit: 50 }
    allow(connection).to receive(:request).and_return(empty_response)

    if defined?(required_params) && required_params.any?
      subject.each_item(**required_params) { |_| } # rubocop:disable Lint/EmptyBlock
    else
      subject.each_item { |_| } # rubocop:disable Lint/EmptyBlock
    end

    expect(connection).to have_received(:request).with(
      :get,
      /.*limit=50.*/
    )
  end

  it "raises ArgumentError when limit exceeds 200" do
    args = defined?(required_params) ? required_params.merge(limit: 201) : { limit: 201 }
    expect do
      subject.each_item(**args) { |_| } # rubocop:disable Lint/EmptyBlock
    end.to raise_error(ArgumentError, "limit cannot exceed 200")
  end

  it "supports early break" do
    allow(connection).to receive(:request).and_return(first_page)

    items = []
    if defined?(required_params) && required_params.any?
      subject.each_item(**required_params) do |item|
        items << item
        break if items.size == 1
      end
    else
      subject.each_item do |item|
        items << item
        break if items.size == 1
      end
    end

    expect(items.size).to eq(1)
  end
end
