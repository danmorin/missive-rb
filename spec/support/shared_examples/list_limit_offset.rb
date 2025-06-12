# frozen_string_literal: true

RSpec.shared_examples "a list endpoint with limit and offset" do |response_key_arg, path, required_params = {}|
  let(:response_key_symbol) { response_key_arg }
  let(:default_response) do
    {
      response_key_arg => [],
      "offset" => 0,
      "limit" => 50
    }
  end
  let(:base_params) { { limit: 50, offset: 0 }.merge(required_params) }

  it "sends GET request with default parameters" do
    expect(connection).to receive(:request).with(
      :get,
      path,
      params: base_params
    ).and_return(default_response)

    if required_params.empty?
      subject.list
    else
      subject.list(**required_params)
    end
  end

  it "sends GET request with custom parameters" do
    custom_params = base_params.merge(limit: 100, offset: 200)
    expect(connection).to receive(:request).with(
      :get,
      path,
      params: custom_params
    ).and_return(default_response)

    if required_params.empty?
      subject.list(limit: 100, offset: 200)
    else
      subject.list(**required_params, limit: 100, offset: 200)
    end
  end

  it "raises ArgumentError when limit exceeds 200" do
    expect do
      if required_params.empty?
        subject.list(limit: 201)
      else
        subject.list(**required_params, limit: 201)
      end
    end.to raise_error(ArgumentError, "limit cannot exceed 200")
  end

  it "returns array of Missive::Object instances" do
    test_data = [{ "id" => "test-1", "name" => "Test Item" }]
    response_with_data = default_response.merge(response_key_arg => test_data)

    expect(connection).to receive(:request).and_return(response_with_data)

    result = if required_params.empty?
               subject.list
             else
               subject.list(**required_params)
             end

    expect(result).to be_an(Array)
    expect(result.length).to eq(1)
    expect(result.first).to be_a(Missive::Object)
    expect(result.first.id).to eq("test-1")
  end
end

RSpec.shared_examples "a paginated list endpoint with limit" do |path, data_key, required_params = {}|
  let(:client_double) { subject.instance_variable_get(:@client) }

  it "uses default limit of 50 when not provided" do
    expected_params = { limit: 50 }.merge(required_params)
    expect(Missive::Paginator).to receive(:each_item).with(
      path: path,
      client: client_double,
      params: expected_params,
      data_key: data_key
    )

    if required_params.empty?
      subject.each_item { |_| } # rubocop:disable Lint/EmptyBlock
    else
      subject.each_item(**required_params) { |_| } # rubocop:disable Lint/EmptyBlock
    end
  end

  it "raises ArgumentError when limit exceeds 200" do
    expect do
      if required_params.empty?
        subject.each_item(limit: 201) { |_| } # rubocop:disable Lint/EmptyBlock
      else
        subject.each_item(**required_params, limit: 201) { |_| } # rubocop:disable Lint/EmptyBlock
      end
    end.to raise_error(ArgumentError, "limit cannot exceed 200")
  end

  it "calls Paginator.each_item with correct parameters" do
    expected_params = { limit: 50 }.merge(required_params)
    expect(Missive::Paginator).to receive(:each_item).with(
      path: path,
      client: client_double,
      params: expected_params,
      data_key: data_key
    )

    if required_params.empty?
      subject.each_item { |_| } # rubocop:disable Lint/EmptyBlock
    else
      subject.each_item(**required_params) { |_| } # rubocop:disable Lint/EmptyBlock
    end
  end

  it "yields Missive::Object instances in each_item" do
    test_item = { "id" => "test-1", "name" => "Test Item" }

    expect(Missive::Paginator).to receive(:each_item).and_yield(test_item)

    yielded_objects = []
    if required_params.empty?
      subject.each_item { |obj| yielded_objects << obj }
    else
      subject.each_item(**required_params) { |obj| yielded_objects << obj }
    end

    expect(yielded_objects.length).to eq(1)
    expect(yielded_objects.first).to be_a(Missive::Object)
    expect(yielded_objects.first.id).to eq("test-1")
  end
end
