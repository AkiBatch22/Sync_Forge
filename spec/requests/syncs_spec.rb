require "rails_helper"

RSpec.describe "Sync operations", type: :request do
  it "filters jobs by status and entity type" do
    create(:sync_job, status: "FAILED")
    create(:sync_job, status: "SUCCEEDED", webhook_event: create(:webhook_event, entity_type: "company",
                                                                  event_type: "company.updated"))
    get "/api/v1/syncs", params: { status: "FAILED", entity_type: "customer" }
    expect(JSON.parse(response.body).length).to eq(1)
  end

  it "returns a chronological event timeline" do
    job = create(:sync_job)
    job.sync_events.create!(correlation_id: job.correlation_id, event_type: "queued", service: "test",
                            severity: "info", message: "queued", occurred_at: 2.minutes.ago)
    job.sync_events.create!(correlation_id: job.correlation_id, event_type: "processing", service: "test",
                            severity: "info", message: "processing", occurred_at: 1.minute.ago)
    get "/api/v1/syncs/#{job.id}/events"
    expect(JSON.parse(response.body).pluck("event_type")).to eq(%w[queued processing])
  end

  it "replays a failed job" do
    job = create(:sync_job, status: "FAILED")
    expect { post "/api/v1/syncs/#{job.id}/replay" }.to change { SyncWorker.jobs.size }.by(1)
    expect(job.reload.status).to eq("QUEUED")
    expect(response).to have_http_status(:accepted)
  end

  it "refuses to replay a successful job" do
    job = create(:sync_job, status: "SUCCEEDED")
    post "/api/v1/syncs/#{job.id}/replay"
    expect(response).to have_http_status(:conflict)
  end
end
