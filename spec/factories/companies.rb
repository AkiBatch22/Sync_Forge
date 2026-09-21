FactoryBot.define do
  factory :company do
    sequence(:external_id) { |n| "CRM-COMP-#{n}" }
    name { "Acme Synthetic Ltd" }
    industry { "Software" }
    employee_count { 100 }
    country { "India" }
    annual_revenue { 1_000_000 }
  end
end
