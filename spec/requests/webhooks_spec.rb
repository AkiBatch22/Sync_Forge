require "rails_helper"

RSpec.describe "CRM webhooks", type: :request do
  let(:correlation_id) { SecureRandom.uuid }
  let(:payload) do
    {
      external_event_id: "evt-request-1", event_type: "customer.created", entity_type: "customer",
      entity_external_id: "CRM-CUST-100", payload: { external_id: "CRM-CUST-100", first_name: "Ada",
                                                       last_name: "Lovelace", email: "ada@example.test",
                                                       country: "India", status: "active" }
    }
  end

  def signed_post(body = payload.to_json, signature: nil, correlation: correlation_id)
    signature ||= OpenSSL::HMAC.hexdigest("SHA256", "development-secret", body)
    post "/api/v1/webhooks/crm", params: body,
         headers: { "CONTENT_TYPE" => "application/json", "X-SyncForge-Signature" => "sha256=#{signature}",
                    "X-Correlation-ID" => correlation }
  end

  it "accepts a valid signed webhook and queues work" do
    expect { signed_post }.to change(WebhookEvent, :count).by(1).and change(SyncJob, :count).by(1)
    expect(response).to have_http_status(:accepted)
    expect(SyncWorker.jobs.size).to eq(1)
  end

  it "rejects an invalid signature without persistence" do
    expect { signed_post(payload.to_json, signature: "bad") }.not_to change(WebhookEvent, :count)
    expect(response).to have_http_status(:unauthorized)
  end

  it "deduplicates repeated delivery at the application layer" do
    signed_post
    expect { signed_post }.not_to change(WebhookEvent, :count)
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["duplicate"]).to be(true)
  end

  it "rejects unsupported event/entity combinations" do
    payload[:event_type] = "company.updated"
    signed_post
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "propagates a valid correlation ID" do
    signed_post
    expect(response.headers["X-Correlation-ID"]).to eq(correlation_id)
    expect(WebhookEvent.last.correlation_id).to eq(correlation_id)
  end

  it "generates a correlation ID when the supplied value is invalid" do
    signed_post(payload.to_json, correlation: "not-a-uuid")
    expect(response.headers["X-Correlation-ID"]).to match(/\A[0-9a-f-]{36}\z/)
  end
end
