FactoryBot.define do
  factory :sync_job do
    association :webhook_event
    source_entity_type { webhook_event.entity_type }
    source_entity_id { webhook_event.entity_external_id }
    destination { "erp" }
    status { "QUEUED" }
    correlation_id { webhook_event.correlation_id }
  end
end
