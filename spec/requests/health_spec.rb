require "rails_helper"

RSpec.describe "Health check", type: :request do
  it "reports all dependency components" do
    allow_any_instance_of(HealthController).to receive(:redis_check).and_return(status: "ok")
    allow_any_instance_of(HealthController).to receive(:sidekiq_check).and_return(status: "ok", processes: 1)
    get "/health"
    expect(JSON.parse(response.body)["checks"].keys).to contain_exactly("rails", "postgresql", "redis", "sidekiq")
    expect(response).to have_http_status(:ok)
  end

  it "reports a degraded state when Redis is unavailable" do
    allow_any_instance_of(HealthController).to receive(:redis_check).and_return(status: "unavailable")
    allow_any_instance_of(HealthController).to receive(:sidekiq_check).and_return(status: "ok", processes: 1)
    get "/health"
    expect(JSON.parse(response.body)["status"]).to eq("degraded")
    expect(response).to have_http_status(:service_unavailable)
  end
end
