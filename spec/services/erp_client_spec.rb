require "rails_helper"

RSpec.describe Clients::ErpClient do
  subject(:client) { described_class.new(base_url: "http://erp.test") }

  let(:arguments) do
    { entity_type: "customer", external_id: "C-1", payload: { external_id: "C-1" },
      event_type: "customer.created", correlation_id: SecureRandom.uuid }
  end

  it "returns parsed content for a successful request" do
    stub_request(:post, "http://erp.test/erp/v1/customers").to_return(status: 201, body: '{"id":1}')
    expect(client.upsert(**arguments)).to eq("id" => 1)
  end

  it "maps a timeout to a recoverable timeout error" do
    stub_request(:post, "http://erp.test/erp/v1/customers").to_timeout
    expect { client.upsert(**arguments) }.to raise_error(IntegrationErrors::ExternalApiTimeout)
  end

  it "maps HTTP 429 to a recoverable rate-limit error" do
    stub_request(:post, "http://erp.test/erp/v1/customers").to_return(status: 429, headers: { "Retry-After" => "9" })
    expect { client.upsert(**arguments) }.to raise_error(IntegrationErrors::RateLimitError) { |error| expect(error.retry_after).to eq(9) }
  end

  it "maps HTTP 500 to a recoverable service error" do
    stub_request(:post, "http://erp.test/erp/v1/customers").to_return(status: 500, body: "synthetic")
    expect { client.upsert(**arguments) }.to raise_error(IntegrationErrors::TemporaryServiceUnavailable)
  end

  it "maps authentication failures to a non-recoverable error" do
    stub_request(:post, "http://erp.test/erp/v1/customers").to_return(status: 401)
    expect { client.upsert(**arguments) }.to raise_error(IntegrationErrors::AuthenticationError)
  end

  it "uses PUT for updated entities" do
    stub = stub_request(:put, "http://erp.test/erp/v1/customers/C-1").to_return(status: 200, body: "{}")
    client.upsert(**arguments.merge(event_type: "customer.updated"))
    expect(stub).to have_been_requested
  end
end
