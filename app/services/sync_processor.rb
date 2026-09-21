class SyncProcessor
  TRANSFORMERS = {
    "customer" => Transformers::CustomerTransformer,
    "company" => Transformers::CompanyTransformer
  }.freeze

  def initialize(sync_job, client: Clients::ErpClient.new, rate_limiter: DestinationRateLimiter.new)
    @sync_job = sync_job
    @webhook = sync_job.webhook_event
    @client = client
    @rate_limiter = rate_limiter
  end

  def call
    return if @sync_job.status == "SUCCEEDED"

    Current.correlation_id = @sync_job.correlation_id
    begin_processing!
    @rate_limiter.check!(@sync_job.destination)
    payload = transformer.new(source_entity).call
    @client.upsert(
      entity_type: @webhook.entity_type,
      external_id: @webhook.entity_external_id,
      payload: payload,
      event_type: @webhook.event_type,
      correlation_id: @sync_job.correlation_id
    )
    succeed!
  rescue IntegrationErrors::RecoverableError => error
    retrying!(error)
    raise
  rescue IntegrationErrors::Error, ActiveRecord::RecordNotFound => error
    fail!(error)
  ensure
    Current.reset
  end

  private

  def transformer
    TRANSFORMERS.fetch(@webhook.entity_type) do
      raise IntegrationErrors::UnsupportedEntityError, "Unsupported entity #{@webhook.entity_type}"
    end
  end

  def source_entity
    model = @webhook.entity_type == "customer" ? Customer : Company
    model.find_by(external_id: @webhook.entity_external_id) || @webhook.payload
  end

  def begin_processing!
    @sync_job.update!(status: "PROCESSING", started_at: Time.current,
                      attempt_count: @sync_job.attempt_count + 1,
                      failure_type: nil, failure_message: nil)
    event!("processing", "Sync processing started")
  end

  def succeed!
    now = Time.current
    @sync_job.update!(status: "SUCCEEDED", completed_at: now, records_processed: 1)
    @webhook.update!(status: "processed", processed_at: now, failure_reason: nil)
    event!("succeeded", "Entity synchronized to ERP")
  end

  def retrying!(error)
    @sync_job.update!(status: "RETRYING", failure_type: error.class.name, failure_message: error.message)
    event!("retrying", error.message, severity: "warn", metadata: { error_type: error.class.name })
  end

  def fail!(error)
    now = Time.current
    @sync_job.update!(status: "FAILED", completed_at: now,
                      failure_type: error.class.name, failure_message: error.message)
    @webhook.update!(status: "failed", processed_at: now, failure_reason: error.message)
    event!("failed", error.message, severity: "error", metadata: { error_type: error.class.name })
  end

  def event!(type, message, severity: "info", metadata: {})
    @sync_job.sync_events.create!(
      correlation_id: @sync_job.correlation_id, event_type: type, service: "sync_worker",
      severity: severity, message: message, metadata: metadata, occurred_at: Time.current
    )
    StructuredLogger.log(level: severity == "error" ? :error : :info, event: type, message: message,
                         webhook_event_id: @webhook.id, sync_job_id: @sync_job.id,
                         customer_id: @webhook.entity_type == "customer" ? @webhook.entity_external_id : nil)
  end
end
