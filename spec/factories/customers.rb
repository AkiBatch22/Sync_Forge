FactoryBot.define do
  factory :customer do
    sequence(:external_id) { |n| "CRM-CUST-#{n}" }
    association :company
    first_name { "Akshat" }
    last_name { "Bajaj" }
    sequence(:email) { |n| "customer#{n}@example.test" }
    phone { "+91-9000000000" }
    country { "India" }
    status { "active" }
  end
end
