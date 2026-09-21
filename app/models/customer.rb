class Customer < ApplicationRecord
  belongs_to :company, optional: true

  validates :external_id, :first_name, :last_name, :status, presence: true
  validates :external_id, uniqueness: true
end
