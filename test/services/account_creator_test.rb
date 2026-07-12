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

  test "subscription creation failure returns a form safe non persisted account" do
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
        assert_no_difference -> { Contact.count } do
          creator = AccountCreator.call(
            account_attributes: {
              name: "Rollback Owner",
              account_type: "client",
              notes: "Keep this note.",
              active: false,
              time_zone: "America/New_York"
            }
          )

          assert_not creator.success?
          assert_not creator.account.persisted?
          assert_nil creator.account.id
          assert_equal "Rollback Owner", creator.account.name
          assert_equal "client", creator.account.account_type
          assert_equal "Keep this note.", creator.account.notes
          assert_not creator.account.active?
          assert_equal "America/New_York", creator.account.time_zone
          assert_includes creator.account.errors[:base], "Status is not included in the list"
          assert_includes creator.account.errors[:base], "Account could not be created with subscription state."
        end
      end
    end
  ensure
    Subscription.define_singleton_method(:default_local_attributes, original_default_attributes)
  end

  test "contact persistence failure returns form safe non persisted account and contact" do
    original_contact_save = Contact.instance_method(:save!)
    Contact.define_method(:save!) do |*args, **kwargs|
      errors.add(:email, "could not be saved")
      raise ActiveRecord::RecordInvalid, self
    end

    assert_no_difference -> { Account.count } do
      assert_no_difference -> { Subscription.count } do
        assert_no_difference -> { Contact.count } do
          creator = AccountCreator.call(
            account_attributes: {
              name: "Contact Rollback Owner",
              account_type: "client",
              notes: "Preserve account copy."
            },
            contact_attributes: {
              name: "Maya Contact",
              email: "maya-contact@example.test",
              phone: "555-0101",
              role: "Owner"
            }
          )

          assert_not creator.success?
          assert_not creator.account.persisted?
          assert_nil creator.account.id
          assert_equal "Contact Rollback Owner", creator.account.name
          assert_equal "Preserve account copy.", creator.account.notes
          assert_not creator.contact.persisted?
          assert_nil creator.contact.id
          assert_same creator.account, creator.contact.account
          assert_equal "Maya Contact", creator.contact.name
          assert_equal "maya-contact@example.test", creator.contact.email
          assert_equal "555-0101", creator.contact.phone
          assert_equal "Owner", creator.contact.role
          assert_includes creator.contact.errors[:base], "Email could not be saved"
          assert_includes creator.account.errors[:base], "Email could not be saved"
          assert_includes creator.account.errors[:base], "Account could not be created with subscription state."
        end
      end
    end
  ensure
    Contact.define_method(:save!, original_contact_save)
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

  test "does not persist account or subscription when account is invalid" do
    assert_no_difference -> { Account.count } do
      assert_no_difference -> { Subscription.count } do
        creator = AccountCreator.call(
          account_attributes: {
            name: "",
            account_type: "client"
          }
        )

        assert_not creator.success?
        assert_not creator.account.persisted?
        assert_nil creator.account.id
        assert_includes creator.account.errors[:name], "can't be blank"
      end
    end
  end
end
