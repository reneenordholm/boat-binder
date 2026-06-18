require "test_helper"

class AccessControlTest < ActionDispatch::IntegrationTest
  test "admin can access owner records across accounts and manage users" do
    setup_access_records
    sign_in_as @admin

    get vessel_path(@owner_a_vessel)
    assert_response :success
    assert_includes response.body, @owner_a_vessel.name

    get vessel_path(@owner_b_vessel)
    assert_response :success
    assert_includes response.body, @owner_b_vessel.name

    get admin_users_path
    assert_response :success
    assert_includes response.body, @owner_a_user.email_address

    new_owner = create_account(name: "Solano Family")
    assert_difference -> { User.count }, 1 do
      post admin_users_path, params: {
        user: {
          name: "Maya Solano",
          email_address: "maya@example.test",
          role: "owner",
          active: "1",
          password: "password",
          password_confirmation: "password",
          account_ids: [ new_owner.id ]
        }
      }
    end

    created_user = User.find_by!(email_address: "maya@example.test")
    assert_redirected_to admin_users_path
    assert created_user.owner?
    assert_equal [ new_owner.id ], created_user.account_memberships.active.pluck(:account_id)
  end

  test "captain can access and manage operational records" do
    setup_access_records
    sign_in_as @captain

    get vessel_path(@owner_b_vessel)
    assert_response :success
    assert_includes response.body, @owner_b_vessel.name

    assert_difference -> { Reminder.count }, 1 do
      post reminders_path, params: {
        reminder: {
          asset_id: @owner_b_vessel.id,
          title: "Replace zincs",
          due_date: Date.tomorrow,
          reminder_type: "maintenance"
        }
      }
    end

    assert_redirected_to reminders_path
  end

  test "owner sees only associated records" do
    setup_access_records
    sign_in_as @owner_a_user

    get vessels_path
    assert_response :success
    assert_includes response.body, @owner_a_vessel.name
    assert_not_includes response.body, @owner_b_vessel.name
    assert_not_includes response.body, "Add vessel"

    get documents_path
    assert_response :success
    assert_includes response.body, @owner_a_document.title
    assert_not_includes response.body, @owner_b_document.title

    get reminders_path
    assert_response :success
    assert_includes response.body, @owner_a_reminder.title
    assert_not_includes response.body, @owner_b_reminder.title
    assert_not_includes response.body, "Mark complete"
  end

  test "owner cannot access another owner's direct object URLs" do
    setup_access_records
    sign_in_as @owner_a_user

    get vessel_path(@owner_b_vessel)
    assert_response :not_found

    get vessel_service_visit_path(@owner_b_vessel, @owner_b_visit)
    assert_response :not_found

    get vessel_path(@owner_a_vessel)
    assert_response :success
    assert_includes response.body, @owner_a_document.title
    assert_not_includes response.body, @owner_b_document.title
  end

  test "owner cannot create update or delete operational records" do
    setup_access_records
    sign_in_as @owner_a_user

    assert_no_difference -> { Asset.count } do
      post vessels_path, params: {
        asset: {
          account_id: @owner_a_account.id,
          name: "Owner Edit",
          active: "1"
        }
      }
    end
    assert_response :forbidden

    patch vessel_path(@owner_a_vessel), params: {
      asset: {
        name: "Renamed by Owner",
        account_id: @owner_a_account.id
      }
    }
    assert_response :forbidden
    assert_not_equal "Renamed by Owner", @owner_a_vessel.reload.name

    assert_no_difference -> { Document.count } do
      delete document_path(@owner_a_document)
    end
    assert_response :forbidden
  end

  test "admin user management is restricted to admins" do
    setup_access_records

    sign_in_as @captain
    get admin_users_path
    assert_response :forbidden

    sign_in_as @owner_a_user
    get admin_users_path
    assert_response :forbidden
  end

  test "login page does not expose demo credentials" do
    get new_session_path

    assert_response :success
    assert_not_includes response.body, "Demo captain:"
    assert_not_includes response.body, "captain@hayesyacht.test / password"
  end

  test "header and dashboard show logged in user role and greeting" do
    setup_access_records

    sign_in_as @admin
    get root_path

    assert_response :success
    assert_includes response.body, "Admin User"
    assert_includes response.body, "Admin"
    assert_includes response.body, "Hello Admin"
    assert_select "a", text: "Owners"

    sign_in_as @captain
    get root_path

    assert_response :success
    assert_includes response.body, "Captain User"
    assert_includes response.body, "Captain"
    assert_includes response.body, "Hello Captain"
    assert_select "a", text: "Owners"

    sign_in_as @owner_a_user
    get root_path

    assert_response :success
    assert_includes response.body, "Avery Elliott"
    assert_includes response.body, "Owner"
    assert_includes response.body, "Hello Avery"
    assert_select "a", text: "Owners", count: 0
  end

  test "admin and captain user forms show global account access as checked and disabled" do
    setup_access_records
    sign_in_as @admin

    get edit_admin_user_path(@admin)
    assert_response :success
    assert_includes response.body, "Admin and captain users have access to all vessels automatically."
    assert_select "input[name='user[account_ids][]'][checked='checked'][disabled='disabled']", count: 2

    get edit_admin_user_path(@captain)
    assert_response :success
    assert_includes response.body, "Admin and captain users have access to all vessels automatically."
    assert_select "input[name='user[account_ids][]'][checked='checked'][disabled='disabled']", count: 2
  end

  test "owner user form shows only explicit account access as editable" do
    setup_access_records
    sign_in_as @admin

    get edit_admin_user_path(@owner_a_user)

    assert_response :success
    assert_select "input[name='user[account_ids][]'][disabled='disabled']", count: 0
    assert_select "input[name='user[account_ids][]'][checked='checked']", count: 1
    assert_select "input[name='user[account_ids][]'][value='#{@owner_a_account.id}'][checked='checked']"
    assert_select "input[name='user[account_ids][]'][value='#{@owner_b_account.id}'][checked='checked']", count: 0
  end

  test "internal user account access params do not create memberships" do
    setup_access_records
    sign_in_as @admin

    assert_no_difference -> { @captain.account_memberships.reload.count } do
      patch admin_user_path(@captain), params: {
        user: {
          name: @captain.name,
          email_address: @captain.email_address,
          role: "captain",
          active: "1",
          password: "",
          password_confirmation: "",
          account_ids: [ @owner_a_account.id, @owner_b_account.id ]
        }
      }
    end

    assert_redirected_to admin_users_path
    assert_empty @captain.account_memberships.active
  end

  test "admin updates owner account access with blank password fields" do
    setup_access_records
    sign_in_as @admin

    patch admin_user_path(@owner_a_user), params: {
      user: {
        name: "Avery Elliott",
        email_address: @owner_a_user.email_address,
        role: "owner",
        active: "1",
        password: "",
        password_confirmation: "",
        account_ids: [ @owner_b_account.id ]
      }
    }

    assert_redirected_to admin_users_path
    assert_equal [ @owner_b_account.id ], @owner_a_user.account_memberships.reload.active.pluck(:account_id)

    delete session_path
    sign_in_as @owner_a_user
    assert_redirected_to root_path
  end

  test "admin edit user renders password mismatch validation without syncing memberships" do
    setup_access_records
    sign_in_as @admin

    patch admin_user_path(@owner_a_user), params: {
      user: {
        name: "Avery Elliott",
        email_address: @owner_a_user.email_address,
        role: "owner",
        active: "1",
        password: "new-password",
        password_confirmation: "different-password",
        account_ids: [ @owner_b_account.id ]
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "Password confirmation"
    assert_equal [ @owner_a_account.id ], @owner_a_user.account_memberships.reload.active.pluck(:account_id)
  end

  test "owner cannot access owner account routes directly" do
    setup_access_records
    sign_in_as @owner_a_user

    get owners_path
    assert_response :forbidden

    get owner_path(@owner_a_account)
    assert_response :forbidden
  end

  private

  def setup_access_records
    @admin = create_user(email: "admin@example.test", role: "admin", name: "Admin User")
    @captain = create_user(email: "captain-access@example.test", role: "captain", name: "Captain User")

    @owner_a_account = create_account(name: "Elliott Family")
    @owner_b_account = create_account(name: "Harbor North")
    @owner_a_vessel = create_vessel(account: @owner_a_account, name: "Blue Meridian")
    @owner_b_vessel = create_vessel(account: @owner_b_account, name: "Tide Runner")

    @owner_a_user = create_user(email: "owner-a@example.test", role: "owner", name: "Avery Elliott")
    @owner_b_user = create_user(email: "owner-b@example.test", role: "owner", name: "Noah Pierce")
    create_account_membership(user: @owner_a_user, account: @owner_a_account)
    create_account_membership(user: @owner_b_user, account: @owner_b_account)

    @owner_a_document = @owner_a_vessel.documents.create!(
      account: @owner_a_account,
      title: "A registration",
      document_type: "registration"
    )
    @owner_b_document = @owner_b_vessel.documents.create!(
      account: @owner_b_account,
      title: "B registration",
      document_type: "registration"
    )

    @owner_a_reminder = @owner_a_vessel.reminders.create!(
      title: "A zincs",
      due_date: Date.tomorrow,
      reminder_type: "maintenance",
      status: "pending"
    )
    @owner_b_reminder = @owner_b_vessel.reminders.create!(
      title: "B zincs",
      due_date: Date.tomorrow,
      reminder_type: "maintenance",
      status: "pending"
    )

    @owner_b_visit = @owner_b_vessel.service_visits.create!(
      performed_by_user: @captain,
      visit_date: Date.current,
      summary: "Other owner report"
    )
  end
end
