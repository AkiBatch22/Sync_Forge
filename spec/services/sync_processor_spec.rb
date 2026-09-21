require "rails_helper"

RSpec.describe SyncProcessor do
  let(:sync_job) { create(:sync_job) }
  let(:client) { instance_double(Clients::ErpClient) }
  let(:limiter) { instance_double(DestinationRateLimiter, check!: true) }

  subject(:process) { described_class.new(sync_job, client: client, rate_limiter: limiter).call }

  it "marks a successful sync and records its timeline" do
    allow(client).to receive(:upsert).and_return("id" => 1)
    process
    expect(sync_job.reload).to have_attributes(status: "SUCCEEDED", records_processed: 1, attempt_count: 1)
    expect(sync_job.sync_events.pluck(:event_type)).to eq(%w[processing succeeded])
  end

  it "does not execute a completed sync twice" do
    sync_job.update!(status: "SUCCEEDED")
    expect(client).not_to receive(:upsert)
    process
  end

  it "marks validation failures as terminal without raising" do
    sync_job.webhook_event.update!(payload: sync_job.webhook_event.payload.merge("email" => nil))
    expect { process }.not_to raise_error
    expect(sync_job.reload).to have_attributes(status: "FAILED", failure_type: "IntegrationErrors::DataValidationError")
  end

  it "marks authentication failures as terminal" do
    allow(client).to receive(:upsert).and_raise(IntegrationErrors::AuthenticationError, "bad credentials")
    process
    expect(sync_job.reload.status).to eq("FAILED")
  end

  it "re-raises retryable timeouts for Sidekiq" do
    allow(client).to receive(:upsert).and_raise(IntegrationErrors::ExternalApiTimeout, "timeout")
    expect { process }.to raise_error(IntegrationErrors::ExternalApiTimeout)
    expect(sync_job.reload.status).to eq("RETRYING")
  end

  it "re-raises rate limiting for delayed retry" do
    allow(limiter).to receive(:check!).and_raise(IntegrationErrors::RateLimitError.new(retry_after: 4))
    expect { process }.to raise_error(IntegrationErrors::RateLimitError)
    expect(sync_job.reload.status).to eq("RETRYING")
  end

  it "increments attempts across retries" do
    allow(client).to receive(:upsert).and_raise(IntegrationErrors::TemporaryServiceUnavailable)
    2.times { expect { process }.to raise_error(IntegrationErrors::TemporaryServiceUnavailable) }
    expect(sync_job.reload.attempt_count).to eq(2)
  end
end
