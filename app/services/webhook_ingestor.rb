class WebhookIngestor
  Result = Data.define(:webhook_event, :duplicate)

  def initialize(attributes)
    @attributes = attributes
  end

  def call
    existing = WebhookEvent.find_by(external_event_id: @attributes[:external_event_id])
    return Result.new(webhook_event: existing, duplicate: true) if existing

    webhook = WebhookEvent.create!(@attributes)
    sync_job = webhook.create_sync_job!(
      source_entity_type: webhook.entity_type,
      source_entity_id: webhook.entity_external_id,
      destination: "erp",
      status: "QUEUED",
      correlation_id: webhook.correlation_id
    )
    sync_job.sync_events.create!(correlation_id: webhook.correlation_id, event_type: "queued",
                                 service: "webhook_ingestion", severity: "info",
                                 message: "Webhook accepted for asynchronous processing", occurred_at: Time.current)
    SyncWorker.perform_async(sync_job.id)
    Result.new(webhook_event: webhook, duplicate: false)
  rescue ActiveRecord::RecordNotUnique
    Result.new(webhook_event: WebhookEvent.find_by!(external_event_id: @attributes[:external_event_id]), duplicate: true)
  end
end
