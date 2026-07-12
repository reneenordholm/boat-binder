require "test_helper"

class AccountCreatorTest < ActiveSupport::TestCase
  test "creates an account with exactly one default local subscription" do
    assert_difference -> { Account.count }, 1 do
      assert_difference -> { Subscription.count }, 1 do
        creator = AccountCreator.call(
          account_attributes: {
            name: "Subscription Owner",
            account_type: "client"
          }
        )

        assert creator.success?
        assert_equal "legacy", creator.account.subscription.plan
        assert_equal "active", creator.account.subscription.status
        assert_equal "local", creator.account.subscription.provider
      end
    end
  end

  test "creates account contact and subscription atomically" do
    creator = AccountCreator.call(
      account_attributes: {
        name: "Contact Owner",
        account_type: "client"
      },
      contact_attributes: {
        name: "Avery Owner",
        email: "avery-owner@example.test",
        role: "Owner"
      }
    )

    assert creator.success?
    assert_equal 1, creator.account.contacts.count
    assert_equal "Avery Owner", creator.account.contacts.first.name
    assert creator.account.subscription.present?
  end

  test "does not persist account when subscription creation fails" do
    original_default_attributes = Subscription.method(:default_local_attributes)
    Subscription.define_singleton_method(:default_local_attributes) do
      {
        plan: "legacy",
        status: "unsupported",
        provider: "local"
      }
    end

    assert_no_difference -> { Account.count } do
      assert_no_difference -> { Subscription.count } do
        creator = AccountCreator.call(
          account_attributes: {
            name: "Rollback Owner",
            account_type: "client"
          }
        )

        assert_not creator.success?
        assert_includes creator.account.errors[:base], "Account could not be created with subscription state."
      end
    end
  ensure
    Subscription.define_singleton_method(:default_local_attributes, original_default_attributes)
  end

  test "does not persist account or subscription when initial contact is invalid" do
    assert_no_difference -> { Account.count } do
      assert_no_difference -> { Subscription.count } do
        creator = AccountCreator.call(
          account_attributes: {
            name: "Invalid Contact Owner",
            account_type: "client"
          },
          contact_attributes: {
            name: "Invalid Contact",
            email: "not-an-email",
            role: "Owner"
          }
        )

        assert_not creator.success?
        assert_includes creator.contact.errors[:email], "is invalid"
      end
    end
  end
end
