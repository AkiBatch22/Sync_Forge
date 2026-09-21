require "rails_helper"

RSpec.describe WebhookEvent, type: :model do
  it "requires a supported event type" do
    event = build(:webhook_event, event_type: "customer.deleted")
    expect(event).not_to be_valid
    expect(event.errors[:event_type]).to include("is not included in the list")
  end

  it "requires a supported entity type" do
    event = build(:webhook_event, entity_type: "invoice")
    expect(event).not_to be_valid
  end

  it "rejects a duplicate external event ID" do
    existing = create(:webhook_event)
    duplicate = build(:webhook_event, external_event_id: existing.external_event_id)
    expect(duplicate).not_to be_valid
  end

  it "owns at most one synchronization job" do
    event = create(:webhook_event)
    create(:sync_job, webhook_event: event)
    duplicate = build(:sync_job, webhook_event: event)
    expect(duplicate).not_to be_valid
  end
end
