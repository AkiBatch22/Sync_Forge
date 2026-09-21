FactoryBot.define do
  factory :webhook_event do
    sequence(:external_event_id) { |n| "evt-#{n}" }
    event_type { "customer.updated" }
    entity_type { "customer" }
    sequence(:entity_external_id) { |n| "CRM-CUST-#{n}" }
    payload do
      { external_id: entity_external_id, first_name: "Akshat", last_name: "Bajaj",
        email: "example@email.com", phone: "+91-9000000000", country: "India", status: "active" }
    end
    status { "received" }
    correlation_id { SecureRandom.uuid }
    received_at { Time.current }
  end
end
