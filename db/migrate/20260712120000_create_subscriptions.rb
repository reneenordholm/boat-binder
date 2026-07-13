class CreateSubscriptions < ActiveRecord::Migration[8.1]
  DEFAULT_PLAN = "legacy"
  DEFAULT_STATUS = "active"
  DEFAULT_PROVIDER = "local"

  def up
    create_table :subscriptions do |t|
      t.references :account, null: false, foreign_key: true, index: false
      t.string :plan, null: false, default: DEFAULT_PLAN
      t.string :status, null: false, default: DEFAULT_STATUS
      t.string :provider, null: false, default: DEFAULT_PROVIDER
      t.string :external_customer_id
      t.string :external_subscription_id
      t.datetime :trial_ends_at
      t.datetime :current_period_ends_at
      t.boolean :cancel_at_period_end, null: false, default: false
      t.datetime :canceled_at
      t.datetime :last_synced_at
      t.timestamps
    end

    add_index :subscriptions, :account_id, unique: true
    add_index :subscriptions, [ :provider, :external_customer_id ], where: "external_customer_id IS NOT NULL"
    add_index :subscriptions, [ :provider, :external_subscription_id ], unique: true, where: "external_subscription_id IS NOT NULL"
    add_check_constraint :subscriptions,
      "plan IN ('legacy', 'starter', 'professional')",
      name: "chk_subscriptions_plan"
    add_check_constraint :subscriptions,
      "status IN ('legacy', 'trialing', 'active', 'past_due', 'canceled', 'expired', 'suspended')",
      name: "chk_subscriptions_status"

    execute <<~SQL.squish
      INSERT INTO subscriptions (account_id, plan, status, provider, created_at, updated_at)
      SELECT accounts.id, #{quote(DEFAULT_PLAN)}, #{quote(DEFAULT_STATUS)}, #{quote(DEFAULT_PROVIDER)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM accounts
      WHERE NOT EXISTS (
        SELECT 1
        FROM subscriptions
        WHERE subscriptions.account_id = accounts.id
      )
    SQL
  end

  def down
    drop_table :subscriptions
  end
end
