# frozen_string_literal: true

RSpec.shared_examples "an offset paginator" do
  let(:path) { "/test" }

  it "stubs three pages: offset 0 → 200 items, offset 200 → 200 items, offset 400 → 42 items" do
    # Page 1: offset 0, limit 200, returns 200 items
    page1 = {
      offset: 0,
      limit: 200,
      data: Array.new(200) { |i| { id: i } }
    }

    # Page 2: offset 200, limit 200, returns 200 items
    page2 = {
      offset: 200,
      limit: 200,
      data: Array.new(200) { |i| { id: i + 200 } }
    }

    # Page 3: offset 400, limit 200, returns 42 items (last page)
    page3 = {
      offset: 400,
      limit: 200,
      data: Array.new(42) { |i| { id: i + 400 } }
    }

    # First request - no offset in params
    allow(connection).to receive(:request).with(:get, "#{path}?limit=200").and_return(page1)
    allow(connection).to receive(:request).with(:get, "#{path}?limit=200&offset=200").and_return(page2)
    allow(connection).to receive(:request).with(:get, "#{path}?limit=200&offset=400").and_return(page3)

    pages = []
    described_class.each_page(path: path, client: client, params: { limit: 200 }) do |page|
      pages << page
    end

    expect(pages.size).to eq(3)
    expect(pages[0][:data].size).to eq(200)
    expect(pages[1][:data].size).to eq(200)
    expect(pages[2][:data].size).to eq(42)

    # Verify requests made
    expect(connection).to have_received(:request).with(:get, "#{path}?limit=200")
    expect(connection).to have_received(:request).with(:get, "#{path}?limit=200&offset=200")
    expect(connection).to have_received(:request).with(:get, "#{path}?limit=200&offset=400")

    # Reset connection doubles for each_item test
    allow(connection).to receive(:request).with(:get, "#{path}?limit=200").and_return(page1)
    allow(connection).to receive(:request).with(:get, "#{path}?limit=200&offset=200").and_return(page2)
    allow(connection).to receive(:request).with(:get, "#{path}?limit=200&offset=400").and_return(page3)

    # Assert total items yielded
    items = []
    described_class.each_item(path: path, client: client, params: { limit: 200 }) do |item|
      items << item
    end
    expect(items.size).to eq(442)
  end

  it "respects max_offset to stop pagination early" do
    page1 = {
      offset: 0,
      limit: 100,
      data: Array.new(100) { |i| { id: i } }
    }

    page2 = {
      offset: 100,
      limit: 100,
      data: Array.new(100) { |i| { id: i + 100 } }
    }

    page3 = {
      offset: 150,
      limit: 100,
      data: Array.new(50) { |i| { id: i + 150 } }
    }

    allow(connection).to receive(:request).with(:get, "#{path}?limit=100").and_return(page1)
    allow(connection).to receive(:request).with(:get, "#{path}?limit=100&offset=100").and_return(page2)
    allow(connection).to receive(:request).with(:get, "#{path}?limit=100&offset=150").and_return(page3)

    pages = []
    described_class.each_page(
      path: path,
      client: client,
      params: { limit: 100 },
      max_offset: 150
    ) do |page|
      pages << page
    end

    expect(pages.size).to eq(3)
    # Should have made all three requests, but the third one with capped offset
    expect(connection).to have_received(:request).with(:get, "#{path}?limit=100")
    expect(connection).to have_received(:request).with(:get, "#{path}?limit=100&offset=100")
    expect(connection).to have_received(:request).with(:get, "#{path}?limit=100&offset=150")
  end
end
