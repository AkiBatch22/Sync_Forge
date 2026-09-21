# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_21_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "companies", force: :cascade do |t|
    t.decimal "annual_revenue", precision: 15, scale: 2
    t.string "country"
    t.datetime "created_at", null: false
    t.integer "employee_count"
    t.string "external_id", null: false
    t.string "industry"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_companies_on_external_id", unique: true
  end

  create_table "customers", force: :cascade do |t|
    t.bigint "company_id"
    t.string "country"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "external_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "phone"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_customers_on_company_id"
    t.index ["email"], name: "index_customers_on_email"
    t.index ["external_id"], name: "index_customers_on_external_id", unique: true
  end

  create_table "erp_companies", force: :cascade do |t|
    t.decimal "annual_revenue", precision: 15, scale: 2
    t.string "company_name", null: false
    t.string "country_code"
    t.datetime "created_at", null: false
    t.integer "employee_total"
    t.string "external_id", null: false
    t.string "industry"
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_erp_companies_on_external_id", unique: true
  end

  create_table "erp_customers", force: :cascade do |t|
    t.string "company_external_id"
    t.string "country_code"
    t.datetime "created_at", null: false
    t.string "customer_status", null: false
    t.string "email_address", null: false
    t.string "external_id", null: false
    t.string "full_name", null: false
    t.string "phone_number"
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_erp_customers_on_external_id", unique: true
  end

  create_table "sync_events", force: :cascade do |t|
    t.uuid "correlation_id", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.text "message", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.string "service", null: false
    t.string "severity", default: "info", null: false
    t.bigint "sync_job_id", null: false
    t.datetime "updated_at", null: false
    t.index ["correlation_id"], name: "index_sync_events_on_correlation_id"
    t.index ["occurred_at"], name: "index_sync_events_on_occurred_at"
    t.index ["sync_job_id"], name: "index_sync_events_on_sync_job_id"
  end

  create_table "sync_jobs", force: :cascade do |t|
    t.integer "attempt_count", default: 0, null: false
    t.datetime "completed_at"
    t.uuid "correlation_id", null: false
    t.datetime "created_at", null: false
    t.string "destination", default: "erp", null: false
    t.text "failure_message"
    t.string "failure_type"
    t.integer "records_processed", default: 0, null: false
    t.string "source_entity_id", null: false
    t.string "source_entity_type", null: false
    t.datetime "started_at"
    t.string "status", default: "QUEUED", null: false
    t.datetime "updated_at", null: false
    t.bigint "webhook_event_id", null: false
    t.index ["correlation_id"], name: "index_sync_jobs_on_correlation_id"
    t.index ["destination"], name: "index_sync_jobs_on_destination"
    t.index ["status"], name: "index_sync_jobs_on_status"
    t.index ["webhook_event_id"], name: "index_sync_jobs_on_webhook_event_id", unique: true
  end

  create_table "webhook_events", force: :cascade do |t|
    t.uuid "correlation_id", null: false
    t.datetime "created_at", null: false
    t.string "entity_external_id", null: false
    t.string "entity_type", null: false
    t.string "event_type", null: false
    t.string "external_event_id", null: false
    t.text "failure_reason"
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.datetime "received_at", null: false
    t.string "status", default: "received", null: false
    t.datetime "updated_at", null: false
    t.index ["correlation_id"], name: "index_webhook_events_on_correlation_id"
    t.index ["entity_type", "entity_external_id"], name: "index_webhook_events_on_entity_type_and_entity_external_id"
    t.index ["external_event_id"], name: "index_webhook_events_on_external_event_id", unique: true
  end

  add_foreign_key "customers", "companies"
  add_foreign_key "sync_events", "sync_jobs"
  add_foreign_key "sync_jobs", "webhook_events"
end
