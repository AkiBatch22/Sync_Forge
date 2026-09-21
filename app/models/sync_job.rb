class SyncJob < ApplicationRecord
  STATUSES = %w[QUEUED PROCESSING RETRYING SUCCEEDED FAILED].freeze

  belongs_to :webhook_event
  has_many :sync_events, -> { order(:occurred_at) }, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :source_entity_type, :source_entity_id, :destination, :correlation_id, presence: true
  validates :webhook_event_id, uniqueness: true

  scope :failed, -> { where(status: "FAILED") }
end
