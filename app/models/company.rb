class Company < ApplicationRecord
  has_many :customers, dependent: :nullify

  validates :external_id, :name, presence: true
  validates :external_id, uniqueness: true
end
