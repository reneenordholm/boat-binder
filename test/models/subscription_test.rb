require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  test "defines plan status and access policy centrally" do
    subscription = Subscription.new(plan: "legacy", status: "trialing", provider: "local")

    assert_includes Subscription::PLANS, "legacy"
    assert_includes Subscription::STATUSES, "past_due"
    assert subscription.trialing?
    assert subscription.access_allowed?

    subscription.status = "active"
    assert subscription.active?
    assert subscription.access_allowed?

    subscription.status = "legacy"
    assert subscription.access_allowed?

    %w[past_due canceled expired suspended].each do |status|
      subscription.status = status
      assert_not subscription.access_allowed?, "#{status} should not allow subscription access"
    end
  end

  test "status and provider predicates describe local and external subscriptions" do
    subscription = Subscription.new(plan: "legacy", status: "past_due", provider: "local")

    assert subscription.past_due?
    assert_not subscription.managed_externally?

    subscription.status = "canceled"
    subscription.provider = "stripe"

    assert subscription.canceled?
    assert subscription.managed_externally?
  end

  test "migration backfills existing accounts without application models" do
    migration_source = Rails.root.join("db/migrate/20260712120000_create_subscriptions.rb").read

    refute_match(/\bAccount\.(reset_column_information|where|update_all|find_each|all|find_by)/, migration_source)
    refute_match(/\bSubscription\.(reset_column_information|where|update_all|find_each|all|find_by)/, migration_source)
    assert_includes migration_source, "INSERT INTO subscriptions"
    assert_includes migration_source, "SELECT accounts.id"
    assert_includes migration_source, "'legacy'"
    assert_includes migration_source, "'active'"
  end

  test "database rejects duplicate subscriptions for an account" do
    account = create_account
    timestamp = Time.current

    assert_raises(ActiveRecord::RecordNotUnique) do
      Subscription.insert_all!([
        {
          account_id: account.id,
          plan: "legacy",
          status: "active",
          provider: "local",
          created_at: timestamp,
          updated_at: timestamp
        }
      ])
    end
  end
end
