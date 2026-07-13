require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  test "defines plan status and access policy centrally" do
    subscription = Subscription.new(plan: "legacy", status: "trialing", provider: "local")

    assert_includes Subscription::PROVIDERS, "local"
    assert_includes Subscription::PROVIDERS, "stripe"
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

  test "provider validation accepts only supported providers" do
    %w[local stripe].each do |provider|
      subscription = Subscription.new(
        account: bare_account(name: "Provider #{provider}"),
        plan: "legacy",
        status: "active",
        provider: provider
      )

      assert subscription.valid?, "#{provider} should be a valid provider"
    end

    [ nil, "", "LOCAL", "Stripe", "strpie", "paypal" ].each do |provider|
      subscription = Subscription.new(
        account: bare_account(name: "Invalid provider #{provider.inspect}"),
        plan: "legacy",
        status: "active",
        provider: provider
      )

      assert_not subscription.valid?, "#{provider.inspect} should be rejected"
      assert_includes subscription.errors[:provider], "is not included in the list"
    end
  end

  test "migration backfills existing accounts without application models" do
    migration_paths = Dir.glob(Rails.root.join("db/migrate/*_create_subscriptions.rb").to_s)
    assert_equal 1, migration_paths.length, "Expected exactly one create_subscriptions migration"

    migration_source = File.read(migration_paths.fetch(0))

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

  test "external subscription id uniqueness allows multiple nil values" do
    first = Subscription.create!(
      account: bare_account(name: "Nil External Subscription One"),
      plan: "legacy",
      status: "active",
      provider: "stripe",
      external_subscription_id: nil
    )
    second = Subscription.create!(
      account: bare_account(name: "Nil External Subscription Two"),
      plan: "legacy",
      status: "active",
      provider: "stripe",
      external_subscription_id: nil
    )

    assert_nil first.external_subscription_id
    assert_nil second.external_subscription_id
  end

  test "external subscription id is unique within provider at model level" do
    Subscription.create!(
      account: bare_account(name: "Stripe External Subscription One"),
      plan: "professional",
      status: "active",
      provider: "stripe",
      external_subscription_id: "sub_duplicate"
    )

    duplicate = Subscription.new(
      account: bare_account(name: "Stripe External Subscription Two"),
      plan: "professional",
      status: "active",
      provider: "stripe",
      external_subscription_id: "sub_duplicate"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_subscription_id], "has already been taken"
  end

  test "external identifier indexes match database integrity expectations" do
    indexes = ActiveRecord::Base.connection.indexes(:subscriptions)

    customer_lookup_index = indexes.find do |index|
      index.columns == %w[provider external_customer_id]
    end
    assert customer_lookup_index
    assert_not customer_lookup_index.unique
    assert_match(/external_customer_id IS NOT NULL/, customer_lookup_index.where.to_s)

    subscription_lookup_index = indexes.find do |index|
      index.columns == %w[provider external_subscription_id]
    end
    assert subscription_lookup_index
    assert subscription_lookup_index.unique
    assert_match(/external_subscription_id IS NOT NULL/, subscription_lookup_index.where.to_s)
  end

  private

  def bare_account(name:)
    Account.create!(name: name, account_type: "client", time_zone: Account::DEFAULT_TIME_ZONE)
  end
end
