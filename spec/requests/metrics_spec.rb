require "rails_helper"

RSpec.describe "Operational metrics", type: :request do
  it "aggregates outcomes, retries, events, and records" do
    create(:sync_job, status: "SUCCEEDED", attempt_count: 1, records_processed: 1,
                      started_at: 2.seconds.ago, completed_at: Time.current)
    create(:sync_job, status: "FAILED", attempt_count: 2, failure_type: "SyntheticFailure",
                      started_at: 5.seconds.ago, completed_at: Time.current)
    get "/api/v1/metrics"
    body = JSON.parse(response.body)
    expect(body).to include("total_sync_jobs" => 2, "successful_sync_jobs" => 1,
                            "failed_sync_jobs" => 1, "success_rate" => 50.0, "retry_rate" => 50.0,
                            "records_synced" => 1)
    expect(body["p95_processing_time_ms"]).to be >= body["average_processing_time_ms"]
  end

  it "returns zero-safe rates with no jobs" do
    get "/api/v1/metrics"
    expect(JSON.parse(response.body)).to include("success_rate" => 0, "p95_processing_time_ms" => 0)
  end
end
