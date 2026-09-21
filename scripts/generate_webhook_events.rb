#!/usr/bin/env ruby
require "json"
require "net/http"
require "openssl"
require "optparse"
require "securerandom"

options = { count: 100, duplicates: 0.05, invalid: 0.02,
            url: ENV.fetch("SYNCFORGE_URL", "http://localhost:3000/api/v1/webhooks/crm") }
OptionParser.new do |parser|
  parser.banner = "Generate synthetic CRM webhook events"
  parser.on("--count=N", Integer) { |value| options[:count] = value }
  parser.on("--duplicates=RATE", Float) { |value| options[:duplicates] = value }
  parser.on("--invalid=RATE", Float) { |value| options[:invalid] = value }
  parser.on("--url=URL") { |value| options[:url] = value }
end.parse!

secret = ENV.fetch("CRM_WEBHOOK_SECRET", "development-secret")
uri = URI(options[:url])
event_ids = []
options[:count].times do |index|
  duplicate = event_ids.any? && rand < options[:duplicates]
  event_id = duplicate ? event_ids.sample : "synthetic-#{SecureRandom.uuid}"
  event_ids << event_id unless duplicate
  invalid = rand < options[:invalid]
  external_id = format("CRM-CUST-%05d", rand(1..10_000))
  event = {
    external_event_id: event_id, event_type: "customer.updated", entity_type: "customer",
    entity_external_id: external_id,
    payload: { external_id: external_id, first_name: "Synthetic", last_name: "Customer #{index}",
               email: invalid ? nil : "synthetic#{index}@example.test", phone: "+91-9000000000",
               country: "India", status: "active" }
  }
  body = JSON.generate(event)
  request = Net::HTTP::Post.new(uri)
  request["Content-Type"] = "application/json"
  request["X-Correlation-ID"] = SecureRandom.uuid
  request["X-SyncForge-Signature"] = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, body)}"
  request.body = body
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
  puts "#{event_id} -> #{response.code}#{duplicate ? " (duplicate)" : ""}#{invalid ? " (invalid payload)" : ""}"
end
