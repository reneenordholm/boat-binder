class InvitationsController < ApplicationController
  INVITATION_INVALID_MESSAGE = "Invitation link is invalid or has expired."

  allow_unauthenticated_access
  before_action :set_user_by_invitation

  def edit
  end

  def update
    @user.assign_attributes(invitation_params.merge(active: true, invitation_accepted_at: Time.current))

    if @user.save
      @user.sessions.destroy_all
      start_new_session_for @user
      redirect_to root_path, notice: "Invitation accepted. Welcome to Boat Binder."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

    def set_user_by_invitation
      @token = params[:token]
      @user = User.find_by_token_for!(:invitation, @token)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to new_session_path, alert: INVITATION_INVALID_MESSAGE
    end

    def invitation_params
      params.permit(:password, :password_confirmation)
    end
end
