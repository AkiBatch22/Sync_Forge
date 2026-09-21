class SyncEvent < ApplicationRecord
  belongs_to :sync_job

  validates :correlation_id, :event_type, :service, :severity, :message, :occurred_at, presence: true
end
