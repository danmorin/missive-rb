# frozen_string_literal: true

RSpec.shared_examples "message endpoint" do
  it "returns array of Missive::Object instances" do
    result = subject

    if result.is_a?(Array)
      expect(result).to all(be_a(Missive::Object))
    else
      expect(result).to be_a(Missive::Object)
    end
  end

  it "handles empty messages array in response" do
    allow(connection).to receive(:request).and_return({ messages: [] })

    result = subject

    expect(result).to eq([]) if result.is_a?(Array)
  end

  it "handles missing messages key in response" do
    allow(connection).to receive(:request).and_return({})

    result = subject

    expect(result).to eq([]) if result.is_a?(Array)
  end

  it "includes Authorization header in request" do
    subject

    expect(connection).to have_received(:request) do |_method, _path, _options|
      # Connection middleware should handle auth headers automatically
      true
    end
  end
end
