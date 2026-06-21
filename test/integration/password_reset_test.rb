require "test_helper"

class PasswordResetTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    ActionMailer::Base.deliveries.clear
  end

  test "password reset request sends instructions synchronously with generic messaging" do
    user = create_user(email: "reset@example.test")

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post passwords_path, params: { email_address: user.email_address }
    end

    assert_redirected_to new_session_path
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Password reset instructions sent (if user with that email address exists)."

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ user.email_address ], mail.to
    assert_equal "Reset your password", mail.subject
    assert_includes mail_body(mail), "http://example.com/passwords/"
  end

  test "password reset request keeps generic messaging when email is unknown" do
    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      post passwords_path, params: { email_address: "missing@example.test" }
    end

    assert_redirected_to new_session_path
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Password reset instructions sent (if user with that email address exists)."
    assert_not_includes response.body, "missing@example.test"
  end

  test "password reset email uses the configured app host for reset links" do
    original_options = PasswordsMailer.default_url_options
    PasswordsMailer.default_url_options = original_options.merge(host: "app.boat-binder.com")
    user = create_user(email: "host-check@example.test")

    mail = PasswordsMailer.reset(user)

    assert_includes mail_body(mail), "http://app.boat-binder.com/passwords/"
  ensure
    PasswordsMailer.default_url_options = original_options
  end

  private

  def mail_body(mail)
    if mail.multipart?
      mail.parts.map { |part| part.body.encoded }.join("\n")
    else
      mail.body.encoded
    end
  end
end
