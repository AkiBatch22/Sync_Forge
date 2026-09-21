class ErpCustomer < ApplicationRecord
  validates :external_id, :full_name, :email_address, :customer_status, presence: true
  validates :external_id, uniqueness: true
end
