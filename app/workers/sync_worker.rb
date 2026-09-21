class SyncWorker
  include Sidekiq::Job

  sidekiq_options queue: :syncs, retry: 5
  sidekiq_retry_in do |count, exception|
    if exception.is_a?(IntegrationErrors::RateLimitError)
      exception.retry_after
    else
      (2**count) * 15
    end
  end
  sidekiq_retries_exhausted do |job, exception|
    sync_job = SyncJob.find_by(id: job["args"].first)
    next unless sync_job

    sync_job.update!(status: "FAILED", completed_at: Time.current,
                     failure_type: exception.class.name, failure_message: exception.message)
    sync_job.sync_events.create!(correlation_id: sync_job.correlation_id, event_type: "retry_exhausted",
                                 service: "sync_worker", severity: "error", message: exception.message,
                                 metadata: { attempts: job["retry_count"] }, occurred_at: Time.current)
  end

  def perform(sync_job_id)
    SyncProcessor.new(SyncJob.find(sync_job_id)).call
  end
end
