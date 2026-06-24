module Admin
  class UsersController < ApplicationController
    before_action :require_admin!
    before_action :set_user, only: %i[edit update]
    before_action :set_accounts, only: %i[new create edit update]

    def index
      @users = User.includes(account_memberships: :account).order(:role, :email_address)
    end

    def new
      @send_invitation = true
      @user = User.new(role: "owner", active: false, invitation_sent_at: Time.current)
    end

    def create
      @user = User.new(user_params)
      assign_admin_managed_user_attributes(@user)
      prepare_invitation if send_invitation?

      if save_user_with_memberships
        deliver_invitation if send_invitation?
        redirect_to admin_users_path, notice: send_invitation? ? "User invited." : "User added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      @user.assign_attributes(user_params)
      assign_admin_managed_user_attributes(@user)

      if save_user_with_memberships
        redirect_to admin_users_path, notice: "User updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def set_accounts
      @accounts = account_access_scope
    end

    def user_params
      permitted = params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
      if @user&.persisted? && permitted[:password].blank? && permitted[:password_confirmation].blank?
        permitted = permitted.except(:password, :password_confirmation)
      end
      permitted
    end

    def assign_admin_managed_user_attributes(user)
      requested_role = params.dig(:user, :role)
      if requested_role.present?
        if User::ROLES.include?(requested_role)
          user.role = requested_role
        else
          @invalid_role_value = requested_role
        end
      end

      return unless params.dig(:user, :active)

      user.active = ActiveModel::Type::Boolean.new.cast(params.dig(:user, :active))
    end

    def send_invitation?
      @send_invitation = if params.dig(:user, :send_invitation).nil?
        @user.new_record? && params.dig(:user, :password).blank?
      else
        ActiveModel::Type::Boolean.new.cast(params.dig(:user, :send_invitation))
      end
    end

    def prepare_invitation
      @user.active = false
      @user.invitation_sent_at = Time.current
      @user.invitation_accepted_at = nil
    end

    def deliver_invitation
      UserInvitationsMailer.invite(@user).deliver_now
      Rails.logger.info("Invitation email delivered for user_id=#{@user.id}")
    rescue *ApplicationMailer::DELIVERY_ERRORS => error
      Rails.logger.error(
        "Invitation email delivery failed for user_id=#{@user.id}: #{error.class}: #{error.message}"
      )
      flash[:alert] = "User was created, but the invitation email could not be sent. Check email configuration."
    end

    def save_user_with_memberships
      saved = false

      User.transaction do
        if admin_managed_user_valid? && @user.save && sync_account_memberships
          saved = true
        else
          raise ActiveRecord::Rollback
        end
      end

      saved
    end

    def admin_managed_user_valid?
      @user.valid?
      if @invalid_role_value.present? && @user.errors[:role].blank?
        @user.errors.add(:role, "is not included in the list")
      end
      @user.errors.empty?
    end

    def sync_account_memberships
      unless @user.owner?
        @user.account_memberships.active.update_all(active: false, updated_at: Time.current)
        return true
      end

      selected_account_ids = Array(params.dig(:user, :account_ids)).compact_blank.map(&:to_i)
      selected_accounts = account_access_scope.where(id: selected_account_ids)

      selected_accounts.find_each do |account|
        membership = @user.account_memberships.find_or_initialize_by(account: account)
        membership.access_level = "read_only"
        membership.active = true
        unless membership.save
          @user.errors.add(:base, "Account access could not be updated.")
          membership.errors.full_messages.each { |message| @user.errors.add(:base, message) }
          return false
        end
      end

      @user.account_memberships.where.not(account_id: selected_account_ids).update_all(active: false, updated_at: Time.current)
      true
    end

    def account_access_scope
      scoped_accounts.active.ordered
    end
  end
end
