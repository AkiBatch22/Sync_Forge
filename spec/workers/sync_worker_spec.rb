require "rails_helper"

RSpec.describe SyncWorker do
  it "marks the job failed and records an event when retries are exhausted" do
    sync_job = create(:sync_job, status: "RETRYING", attempt_count: 6)
    error = IntegrationErrors::TemporaryServiceUnavailable.new("ERP remained unavailable")

    described_class.sidekiq_retries_exhausted_block.call(
      { "args" => [ sync_job.id ], "retry_count" => 5 }, error
    )

    expect(sync_job.reload).to have_attributes(
      status: "FAILED", failure_type: "IntegrationErrors::TemporaryServiceUnavailable",
      failure_message: "ERP remained unavailable"
    )
    expect(sync_job.sync_events.last).to have_attributes(event_type: "retry_exhausted", severity: "error")
  end
end
