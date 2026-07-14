class CreateBillingWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_webhook_events do |t|
      t.string :provider, null: false
      t.string :external_event_id, null: false
      t.string :event_type, null: false
      t.boolean :livemode, null: false, default: false
      t.string :api_version
      t.string :status, null: false, default: "received"
      t.datetime :processed_at
      t.datetime :failed_at
      t.string :error_code
      t.timestamps
    end

    add_index :billing_webhook_events, [ :provider, :external_event_id ], unique: true
    add_index :billing_webhook_events, [ :provider, :status ]
    add_index :billing_webhook_events, [ :provider, :event_type ]
    add_check_constraint :billing_webhook_events,
      "provider IN ('local', 'stripe')",
      name: "chk_billing_webhook_events_provider"
    add_check_constraint :billing_webhook_events,
      "status IN ('received', 'processed', 'ignored', 'failed')",
      name: "chk_billing_webhook_events_status"
  end
end
