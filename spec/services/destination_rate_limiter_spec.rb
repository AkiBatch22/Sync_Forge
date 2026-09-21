require "rails_helper"

RSpec.describe DestinationRateLimiter do
  let(:redis) { instance_double(Redis) }

  it "allows requests within the destination budget" do
    allow(redis).to receive(:incr).and_return(1)
    allow(redis).to receive(:expire)
    expect { described_class.new(redis: redis).check!("erp") }.not_to raise_error
  end

  it "delays work after the destination budget is exhausted" do
    allow(redis).to receive(:incr).and_return(101)
    expect { described_class.new(redis: redis).check!("erp") }.to raise_error(IntegrationErrors::RateLimitError)
  end

  it "fails open and logs when Redis is unavailable" do
    allow(redis).to receive(:incr).and_raise(Redis::CannotConnectError)
    expect { described_class.new(redis: redis).check!("erp") }.not_to raise_error
  end
end
