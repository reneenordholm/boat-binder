require "test_helper"

class OwnerManagementTest < ActionDispatch::IntegrationTest
  test "captain creates and edits an owner with contact details and active status" do
    sign_in_as

    assert_difference -> { Account.count }, 1 do
      post owners_path, params: {
        account: {
          name: "Solano Family",
          notes: "Prefers text updates.",
          active: "1"
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

    patch owner_path(owner), params: {
      account: {
        name: "Solano Family",
        notes: "Inactive for winter.",
        active: "0"
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
    assert_equal "maya.solano@example.test", owner.primary_contact.email
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
end
