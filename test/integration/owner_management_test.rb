require "test_helper"

class OwnerManagementTest < ActionDispatch::IntegrationTest
  test "captain creates and edits an owner with contact details and active status" do
    sign_in_as create_user(email: "admin-owner-timezone@example.test", role: "admin")

    assert_difference -> { Account.count }, 1 do
      post owners_path, params: {
        account: {
          name: "Solano Family",
          notes: "Prefers text updates.",
          active: "1",
          time_zone: "America/New_York"
        },
        contact: {
          name: "Maya Solano",
          email: "maya@example.test",
          phone: "555-0199"
        }
      }
    end

    owner = Account.find_by!(name: "Solano Family")
    assert_redirected_to owner_path(owner)
    assert_equal "Maya Solano", owner.primary_contact.name
    assert_equal "America/New_York", owner.time_zone

    patch owner_path(owner), params: {
      account: {
        name: "Solano Family",
        notes: "Inactive for winter.",
        active: "0",
        time_zone: "America/Chicago"
      },
      contact: {
        name: "Maya Solano",
        email: "maya.solano@example.test",
        phone: "555-0200"
      }
    }

    owner.reload
    assert_redirected_to owner_path(owner)
    assert_not owner.active?
    assert_equal "America/Chicago", owner.time_zone
    assert_equal "maya.solano@example.test", owner.primary_contact.email
  end

  test "owner form shows and preserves selected time zone after validation errors" do
    sign_in_as

    get new_owner_path

    assert_response :success
    assert_select "label[for='account_time_zone']", "Time zone"
    assert_select "select[name='account[time_zone]'] option[value='America/Los_Angeles'][selected]"

    assert_no_difference -> { Account.count } do
      post owners_path, params: {
        account: {
          name: "",
          active: "1",
          time_zone: "America/New_York"
        },
        contact: {
          name: "Maya Solano",
          email: "maya@example.test"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "select[name='account[time_zone]'] option[value='America/New_York'][selected]"
  end

  test "inactive owners are hidden by default but can be included" do
    sign_in_as
    active_owner = create_account(name: "Active Owner")
    inactive_owner = create_account(name: "Inactive Owner")
    inactive_owner.update!(active: false)

    get owners_path
    assert_response :success
    assert_includes response.body, active_owner.name
    assert_not_includes response.body, inactive_owner.name

    get owners_path(include_inactive: "1")
    assert_response :success
    assert_includes response.body, inactive_owner.name
  end

  test "owner page lists linked owner users for the account only" do
    admin = create_user(email: "admin-linked-owners@example.test", role: "admin")
    account = create_account(name: "Elliott Family")
    other_account = create_account(name: "Harbor North")
    account.contacts.create!(name: "Manual Owner", email: "manual-owner@example.test", role: "Owner")
    linked_owner = create_user(email: "linked-owner@example.test", role: "owner", name: "Avery Elliott")
    pending_owner = User.create!(
      email_address: "pending-owner@example.test",
      role: "owner",
      active: false,
      invitation_sent_at: Time.current
    )
    other_owner = create_user(email: "other-account-owner@example.test", role: "owner", name: "Other Owner")
    create_account_membership(user: linked_owner, account: account)
    create_account_membership(user: pending_owner, account: account)
    create_account_membership(user: other_owner, account: other_account)
    sign_in_as admin

    get owner_path(account)

    assert_response :success
    assert_includes response.body, "Boat Binder account access"
    assert_includes response.body, "Avery Elliott"
    assert_includes response.body, "linked-owner@example.test"
    assert_includes response.body, "pending-owner@example.test"
    assert_includes response.body, "Invitation pending"
    assert_includes response.body, "Email recipient eligible"
    assert_includes response.body, "Not email eligible"
    assert_includes response.body, "Additional contact information"
    assert_includes response.body, "manual-owner@example.test"
    assert_not_includes response.body, "other-account-owner@example.test"
    assert_select "a[href='#{new_admin_user_path}']", text: "Invite owner user"
    assert_select "a[href='#{edit_admin_user_path(linked_owner)}']", text: "Manage user"
  end

  test "owner page renders empty account access and contact states" do
    admin = create_user(email: "admin-empty-owner-access@example.test", role: "admin")
    account = create_account(name: "No Contact Owner")
    sign_in_as admin

    get owner_path(account)

    assert_response :success
    assert_includes response.body, "No linked owner users yet."
    assert_includes response.body, "No additional contact information saved yet."
  end

  test "owner form clarifies manual contact information does not grant access" do
    sign_in_as create_user(email: "admin-owner-contact-copy@example.test", role: "admin")

    get new_owner_path

    assert_response :success
    assert_includes response.body, "Additional contact information"
    assert_includes response.body, "Use this for a contact who does not have Boat Binder access."
    assert_includes response.body, "Transactional emails are sent to linked active owner users when available."
  end
end
