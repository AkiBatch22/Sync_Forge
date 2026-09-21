class WebhookEvent < ApplicationRecord
  SUPPORTED_EVENTS = %w[customer.created customer.updated company.created company.updated].freeze

  has_one :sync_job, dependent: :destroy

  validates :external_event_id, :event_type, :entity_type, :entity_external_id,
            :correlation_id, :received_at, presence: true
  validates :external_event_id, uniqueness: true
  validates :event_type, inclusion: { in: SUPPORTED_EVENTS }
  validates :entity_type, inclusion: { in: %w[customer company] }
end
