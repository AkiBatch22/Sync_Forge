class CreateSyncforgeSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :external_id, null: false
      t.string :name, null: false
      t.string :industry
      t.integer :employee_count
      t.string :country
      t.decimal :annual_revenue, precision: 15, scale: 2
      t.timestamps
    end
    add_index :companies, :external_id, unique: true

    create_table :customers do |t|
      t.string :external_id, null: false
      t.references :company, null: true, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email
      t.string :phone
      t.string :country
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :customers, :external_id, unique: true
    add_index :customers, :email

    create_table :webhook_events do |t|
      t.string :external_event_id, null: false
      t.string :event_type, null: false
      t.string :entity_type, null: false
      t.string :entity_external_id, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :status, null: false, default: "received"
      t.uuid :correlation_id, null: false
      t.datetime :received_at, null: false
      t.datetime :processed_at
      t.text :failure_reason
      t.timestamps
    end
    add_index :webhook_events, :external_event_id, unique: true
    add_index :webhook_events, :correlation_id
    add_index :webhook_events, %i[entity_type entity_external_id]

    create_table :sync_jobs do |t|
      t.references :webhook_event, null: false, foreign_key: true, index: { unique: true }
      t.string :source_entity_type, null: false
      t.string :source_entity_id, null: false
      t.string :destination, null: false, default: "erp"
      t.string :status, null: false, default: "QUEUED"
      t.uuid :correlation_id, null: false
      t.integer :attempt_count, null: false, default: 0
      t.integer :records_processed, null: false, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.string :failure_type
      t.text :failure_message
      t.timestamps
    end
    add_index :sync_jobs, :status
    add_index :sync_jobs, :destination
    add_index :sync_jobs, :correlation_id

    create_table :sync_events do |t|
      t.references :sync_job, null: false, foreign_key: true
      t.uuid :correlation_id, null: false
      t.string :event_type, null: false
      t.string :service, null: false
      t.string :severity, null: false, default: "info"
      t.text :message, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :sync_events, :correlation_id
    add_index :sync_events, :occurred_at

    create_table :erp_companies do |t|
      t.string :external_id, null: false
      t.string :company_name, null: false
      t.string :industry
      t.integer :employee_total
      t.string :country_code
      t.decimal :annual_revenue, precision: 15, scale: 2
      t.timestamps
    end
    add_index :erp_companies, :external_id, unique: true

    create_table :erp_customers do |t|
      t.string :external_id, null: false
      t.string :full_name, null: false
      t.string :email_address, null: false
      t.string :phone_number
      t.string :country_code
      t.string :customer_status, null: false
      t.string :company_external_id
      t.timestamps
    end
    add_index :erp_customers, :external_id, unique: true
  end
end
