require "faker"

puts "Creating synthetic SyncForge demo data (seed=42)..."
Faker::Config.random = Random.new(42)
countries = Transformers::BaseTransformer::COUNTRY_CODES.keys

companies = 500.times.map do |index|
  Company.find_or_create_by!(external_id: format("CRM-COMP-%04d", index + 1)) do |company|
    company.name = Faker::Company.name
    company.industry = Faker::Company.industry
    company.employee_count = rand(5..10_000)
    company.country = countries.sample
    company.annual_revenue = Faker::Number.decimal(l_digits: 7, r_digits: 2)
  end
end

10_000.times do |index|
  Customer.find_or_create_by!(external_id: format("CRM-CUST-%05d", index + 1)) do |customer|
    customer.company = rand < 0.01 ? nil : companies.sample
    customer.first_name = Faker::Name.first_name
    customer.last_name = Faker::Name.last_name
    customer.email = rand < 0.03 ? nil : Faker::Internet.unique.email
    customer.phone = rand < 0.02 ? "BAD-PHONE-#{index}" : Faker::PhoneNumber.phone_number
    customer.country = rand < 0.01 ? "Unknownland" : countries.sample
    customer.status = %w[active active active inactive prospect].sample
  end
end

20.times do |index|
  customer = Customer.offset(index).first
  webhook = WebhookEvent.find_or_create_by!(external_event_id: "SYNTHETIC-HISTORY-#{index + 1}") do |event|
    event.event_type = "customer.updated"
    event.entity_type = "customer"
    event.entity_external_id = customer.external_id
    event.payload = customer.attributes.slice("external_id", "first_name", "last_name", "email", "phone", "country", "status")
    event.status = index < 16 ? "processed" : "failed"
    event.correlation_id = SecureRandom.uuid
    event.received_at = (index + 1).hours.ago
    event.processed_at = event.received_at + rand(1..8).seconds
    event.failure_reason = "Synthetic validation failure" if index >= 16
  end
  next if webhook.sync_job

  status = index < 16 ? "SUCCEEDED" : "FAILED"
  webhook.create_sync_job!(source_entity_type: "customer", source_entity_id: customer.external_id,
                           destination: "erp", status: status, correlation_id: webhook.correlation_id,
                           attempt_count: index.even? ? 1 : 2, records_processed: status == "SUCCEEDED" ? 1 : 0,
                           started_at: webhook.received_at, completed_at: webhook.processed_at,
                           failure_type: status == "FAILED" ? "SyntheticFailure" : nil,
                           failure_message: webhook.failure_reason)
end

puts "Synthetic data ready: #{Company.count} companies, #{Customer.count} customers, #{SyncJob.count} historical jobs."
