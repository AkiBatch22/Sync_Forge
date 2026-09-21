require "rails_helper"

RSpec.describe SyncJob, type: :model do
  it "accepts every documented lifecycle status" do
    described_class::STATUSES.each do |status|
      expect(build(:sync_job, status: status)).to be_valid
    end
  end

  it "rejects an unknown status" do
    expect(build(:sync_job, status: "CANCELLED")).not_to be_valid
  end

  it "returns only failed jobs from the failed scope" do
    failed = create(:sync_job, status: "FAILED")
    create(:sync_job, status: "SUCCEEDED")
    expect(described_class.failed).to contain_exactly(failed)
  end

  it "orders timeline events chronologically" do
    job = create(:sync_job)
    later = job.sync_events.create!(correlation_id: job.correlation_id, event_type: "later", service: "test",
                                    severity: "info", message: "later", occurred_at: 1.minute.from_now)
    earlier = job.sync_events.create!(correlation_id: job.correlation_id, event_type: "earlier", service: "test",
                                      severity: "info", message: "earlier", occurred_at: Time.current)
    expect(job.sync_events.reload).to eq([ earlier, later ])
  end
end
