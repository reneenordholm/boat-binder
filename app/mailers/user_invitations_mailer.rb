class UserInvitationsMailer < ApplicationMailer
  def invite(user)
    @user = user
    @invitation_url = edit_invitation_url(user.generate_token_for(:invitation))

    mail subject: "You've been invited to Boat Binder", to: user.email_address
  end
end
