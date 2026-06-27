require "test_helper"
require "cgi"

class UserInvitationTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
    @admin = create_user(email: "admin-invites@example.test", role: "admin")
  end

  teardown do
    ActionMailer::Base.deliveries.clear
  end

  test "admin invites owner user who accepts and can log in" do
    account = create_account(name: "Elliott Family")
    sign_in_as @admin

    assert_difference -> { User.count }, 1 do
      assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
        post admin_users_path, params: {
          user: invite_params(
            name: "Avery Elliott",
            email_address: "avery-invited@example.test",
            role: "owner",
            account_ids: [ account.id ]
          )
        }
      end
    end

    invited_user = User.find_by!(email_address: "avery-invited@example.test")
    assert_redirected_to admin_users_path
    assert invited_user.invitation_pending?
    assert_not invited_user.active?
    assert_nil invited_user.password_digest
    assert_not invited_user.authenticate("anything")
    assert_equal [ account.id ], invited_user.account_memberships.active.pluck(:account_id)

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ invited_user.email_address ], mail.to
    assert_equal "You've been invited to Boat Binder", mail.subject

    token = invitation_token_from(mail)
    get edit_invitation_path(token)
    assert_response :success
    assert_includes response.body, invited_user.email_address

    put invitation_path(token), params: {
      password: "new-password",
      password_confirmation: "new-password"
    }

    assert_redirected_to root_path
    invited_user.reload
    assert invited_user.active?
    assert invited_user.invitation_accepted?

    delete session_path
    post session_path, params: {
      email_address: invited_user.email_address,
      password: "new-password"
    }
    assert_redirected_to root_path
  end

  test "blank-password user creation defaults to invitation consistently after save" do
    sign_in_as @admin

    assert_difference -> { User.count }, 1 do
      assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
        post admin_users_path, params: {
          user: invite_params(email_address: "default-invited@example.test").except(:send_invitation)
        }
      end
    end

    invited_user = User.find_by!(email_address: "default-invited@example.test")
    assert_redirected_to admin_users_path
    assert_equal "User invited.", flash[:notice]
    assert invited_user.invitation_pending?
    assert_nil invited_user.password_digest
  end

  test "new invitation form reflects inactive model value" do
    sign_in_as @admin

    get new_admin_user_path

    assert_response :success
    assert_select "input[type=checkbox][name='user[send_invitation]'][checked]"
    assert_select "input[type=checkbox][name='user[active]']" do |elements|
      assert_nil elements.first["checked"]
    end
  end

  test "invited user clears submitted password fields" do
    sign_in_as @admin

    assert_difference -> { User.count }, 1 do
      assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
        post admin_users_path, params: {
          user: invite_params(
            email_address: "password-cleared@example.test",
            password: "admin-entered-password",
            password_confirmation: "admin-entered-password"
          )
        }
      end
    end

    invited_user = User.find_by!(email_address: "password-cleared@example.test")
    assert_not invited_user.active?
    assert invited_user.invitation_pending?
    assert_not invited_user.invitation_accepted?
    assert_not_nil invited_user.invitation_sent_at
    assert_nil invited_user.invitation_accepted_at
    assert_nil invited_user.password
    assert_nil invited_user.password_confirmation
    assert_nil invited_user.password_digest
    assert_not invited_user.authenticate("admin-entered-password")
  end

  test "invitation delivery failure shows accurate alert instead of invited notice" do
    sign_in_as @admin
    failed_delivery = Object.new
    failed_delivery.define_singleton_method(:deliver_now) do
      raise Errno::ECONNREFUSED, "connect(2) for localhost port 25"
    end
    original_invite = UserInvitationsMailer.method(:invite)
    UserInvitationsMailer.define_singleton_method(:invite) { |_user| failed_delivery }

    assert_difference -> { User.count }, 1 do
      assert_no_difference -> { ActionMailer::Base.deliveries.size } do
        post admin_users_path, params: {
          user: invite_params(email_address: "delivery-failed@example.test")
        }
      end
    end

    invited_user = User.find_by!(email_address: "delivery-failed@example.test")
    assert invited_user.invitation_pending?
    assert_redirected_to admin_users_path
    assert_equal Admin::UsersController::INVITATION_DELIVERY_FAILURE_MESSAGE, flash[:alert]
    assert_not_equal "User invited.", flash[:notice]
  ensure
    UserInvitationsMailer.define_singleton_method(:invite, original_invite) if original_invite
  end

  test "manual user creation with password creates active user by default" do
    sign_in_as @admin

    post admin_users_path, params: {
      user: invite_params(
        email_address: "manual-active@example.test",
        send_invitation: "0",
        password: "manual-password",
        password_confirmation: "manual-password"
      ).except(:active)
    }

    user = User.find_by!(email_address: "manual-active@example.test")
    assert_redirected_to admin_users_path
    assert_equal "User added.", flash[:notice]
    assert user.active?
    assert_not user.invitation_pending?
    assert user.authenticate("manual-password")
  end

  test "manual user creation can still be explicitly inactive" do
    sign_in_as @admin

    post admin_users_path, params: {
      user: invite_params(
        email_address: "manual-inactive@example.test",
        active: "0",
        send_invitation: "0",
        password: "manual-password",
        password_confirmation: "manual-password"
      )
    }

    user = User.find_by!(email_address: "manual-inactive@example.test")
    assert_redirected_to admin_users_path
    assert_not user.active?
    assert_not user.invitation_pending?
    assert user.authenticate("manual-password")
  end

  test "accepted invitation cannot be reused" do
    invited_user = create_invited_user
    token = invited_user.generate_token_for(:invitation)

    put invitation_path(token), params: {
      password: "new-password",
      password_confirmation: "new-password"
    }

    assert_redirected_to root_path
    delete session_path

    get edit_invitation_path(token)

    assert_redirected_to new_session_path
    follow_redirect!
    assert_includes response.body, InvitationsController::INVITATION_INVALID_MESSAGE
  end

  test "expired invitation fails gracefully" do
    invited_user = create_invited_user
    token = invited_user.generate_token_for(:invitation)

    travel User::INVITATION_EXPIRES_IN + 1.day do
      get edit_invitation_path(token)
    end

    assert_redirected_to new_session_path
    follow_redirect!
    assert_includes response.body, InvitationsController::INVITATION_INVALID_MESSAGE
  end

  test "re-sent invitation within the same second invalidates the previous token" do
    invited_user = create_invited_user
    first_sent_at = Time.zone.local(2026, 6, 24, 12, 0, 0, 100_000)
    second_sent_at = Time.zone.local(2026, 6, 24, 12, 0, 0, 900_000)
    invited_user.update!(invitation_sent_at: first_sent_at)
    old_token = invited_user.generate_token_for(:invitation)

    invited_user.update!(invitation_sent_at: second_sent_at)

    get edit_invitation_path(old_token)
    assert_redirected_to new_session_path
    follow_redirect!
    assert_includes response.body, InvitationsController::INVITATION_INVALID_MESSAGE

    get edit_invitation_path(invited_user.generate_token_for(:invitation))
    assert_response :success
  end

  test "active users are not invitation pending even when invitation timestamp remains" do
    invited_user = create_invited_user
    invited_user.update!(
      active: true,
      invitation_accepted_at: nil,
      password: "active-password",
      password_confirmation: "active-password"
    )

    assert_not invited_user.invitation_pending?
  end

  test "pending invited users cannot sign in before accepting" do
    invited_user = create_invited_user
    assert_nil invited_user.password_digest

    post session_path, params: {
      email_address: invited_user.email_address,
      password: "anything"
    }

    assert_redirected_to new_session_path
    follow_redirect!
    assert_select "div", text: Authentication::GENERIC_LOGIN_FAILURE_MESSAGE
  end

  test "non admin users cannot send invitations" do
    captain = create_user(email: "captain-invite@example.test", role: "captain")
    sign_in_as captain

    assert_no_difference -> { User.count } do
      assert_no_difference -> { ActionMailer::Base.deliveries.size } do
        post admin_users_path, params: {
          user: invite_params(email_address: "blocked@example.test")
        }
      end
    end

    assert_redirected_to root_path
  end

  test "internal role invites do not create account memberships" do
    account = create_account(name: "Harbor North")
    sign_in_as @admin

    %w[admin captain].each do |role|
      post admin_users_path, params: {
        user: invite_params(
          email_address: "#{role}-invited@example.test",
          role: role,
          account_ids: [ account.id ]
        )
      }

      invited_user = User.find_by!(email_address: "#{role}-invited@example.test")
      assert_equal role, invited_user.role
      assert_empty invited_user.account_memberships.active
    end
  end

  private

  def invite_params(attributes = {})
    {
      name: "Invited User",
      email_address: "invited@example.test",
      role: "owner",
      active: "1",
      send_invitation: "1",
      password: "",
      password_confirmation: "",
      account_ids: []
    }.merge(attributes)
  end

  def create_invited_user
    User.create!(
      name: "Pending Owner",
      email_address: "pending-owner@example.test",
      role: "owner",
      active: false,
      invitation_sent_at: Time.current,
      password_digest: nil
    )
  end

  def invitation_token_from(mail)
    text = mail.text_part&.body&.decoded || mail.body.decoded
    CGI.unescape(text.match(%r{/invitations/([^/\s]+)/edit})[1])
  end
end
