module Api
  module V1
    class SyncsController < ApplicationController
      def index
        jobs = filtered_scope.order(created_at: :desc).limit(100)
        render json: jobs.map { |job| serialize(job) }
      end

      def show
        render json: serialize(sync_job, include_events: true)
      end

      def failed
        jobs = filtered_scope.failed.order(created_at: :desc).limit(100)
        render json: jobs.map { |job| serialize(job) }
      end

      def events
        render json: sync_job.sync_events.map { |event| event.as_json(except: %i[created_at updated_at]) }
      end

      def replay
        return render json: { error: "successful jobs cannot be replayed" }, status: :conflict if sync_job.status == "SUCCEEDED"

        sync_job.update!(status: "QUEUED", completed_at: nil, failure_type: nil, failure_message: nil)
        sync_job.sync_events.create!(correlation_id: sync_job.correlation_id, event_type: "replayed",
                                     service: "sync_api", severity: "info", message: "Manual replay queued",
                                     occurred_at: Time.current)
        SyncWorker.perform_async(sync_job.id)
        render json: serialize(sync_job), status: :accepted
      end

      private

      def sync_job
        @sync_job ||= SyncJob.find(params[:id])
      end

      def filtered_scope
        scope = SyncJob.all
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where(destination: params[:destination]) if params[:destination].present?
        scope = scope.where(source_entity_type: params[:entity_type]) if params[:entity_type].present?
        scope
      end

      def serialize(job, include_events: false)
        result = job.as_json(except: %i[updated_at])
        result["events"] = job.sync_events.as_json(except: %i[created_at updated_at]) if include_events
        result
      end
    end
  end
end
