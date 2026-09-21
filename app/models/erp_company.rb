class ErpCompany < ApplicationRecord
  validates :external_id, :company_name, presence: true
  validates :external_id, uniqueness: true
end
