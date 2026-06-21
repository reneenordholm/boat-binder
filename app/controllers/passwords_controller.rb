class PasswordsController < ApplicationController
  RESET_REQUEST_NOTICE = "If an account exists for that email, reset instructions will be sent shortly."
  MAIL_DELIVERY_ERRORS = [
    Net::SMTPError,
    IOError,
    SocketError,
    SystemCallError,
    Timeout::Error
  ].freeze

  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      deliver_password_reset(user)
    end

    redirect_to new_session_path, notice: RESET_REQUEST_NOTICE
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "Password has been reset."
    else
      redirect_to edit_password_path(params[:token]), alert: "Passwords did not match."
    end
  end

  private
    def deliver_password_reset(user)
      PasswordsMailer.reset(user).deliver_now
      Rails.logger.info("Password reset email delivered for user_id=#{user.id}")
    rescue *MAIL_DELIVERY_ERRORS => error
      Rails.logger.error(
        "Password reset email delivery failed for user_id=#{user.id}: #{error.class}: #{error.message}"
      )
    end

    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
    end
end
