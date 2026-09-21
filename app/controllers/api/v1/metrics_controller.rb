module Api
  module V1
    class MetricsController < ApplicationController
      def show
        jobs = SyncJob.all
        total = jobs.count
        durations = jobs.where.not(started_at: nil, completed_at: nil)
                        .pluck(Arel.sql("EXTRACT(EPOCH FROM (completed_at - started_at)) * 1000"))
                        .map(&:to_f).sort
        render json: {
          total_sync_jobs: total,
          successful_sync_jobs: jobs.where(status: "SUCCEEDED").count,
          failed_sync_jobs: jobs.where(status: "FAILED").count,
          success_rate: percentage(jobs.where(status: "SUCCEEDED").count, total),
          retry_rate: percentage(jobs.where("attempt_count > 1").count, total),
          average_processing_time_ms: durations.any? ? (durations.sum / durations.length).round(2) : 0,
          p95_processing_time_ms: percentile(durations, 0.95),
          jobs_by_status: jobs.group(:status).count,
          failures_by_type: jobs.where(status: "FAILED").group(:failure_type).count,
          events_processed: WebhookEvent.where(status: %w[processed failed]).count,
          records_synced: jobs.sum(:records_processed)
        }
      end

      private

      def percentage(numerator, denominator)
        denominator.zero? ? 0 : (numerator.fdiv(denominator) * 100).round(2)
      end

      def percentile(values, percentile)
        return 0 if values.empty?

        values[((values.length - 1) * percentile).ceil].round(2)
      end
    end
  end
end
