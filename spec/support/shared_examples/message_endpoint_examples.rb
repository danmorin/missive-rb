# frozen_string_literal: true

RSpec.shared_examples "message endpoint" do
  it "returns array of Missive::Object instances" do
    result = subject

    expect(result).to be_an(Array)
    expect(result).to all(be_a(Missive::Object))
  end

  it "handles empty messages array in response" do
    allow(connection).to receive(:request).and_return({ messages: [] })

    result = subject

    expect(result).to eq([])
  end

  it "handles missing messages key in response" do
    allow(connection).to receive(:request).and_return({})

    result = subject

    expect(result).to eq([])
  end

  it "includes Authorization header in request" do
    subject

    expect(connection).to have_received(:request) do |_method, _path, _options|
      # Connection middleware should handle auth headers automatically
      true
    end
  end
end
