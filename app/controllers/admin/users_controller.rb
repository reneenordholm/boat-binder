module Admin
  class UsersController < ApplicationController
    before_action :require_admin!
    before_action :set_user, only: %i[edit update]
    before_action :set_accounts, only: %i[new create edit update]

    def index
      @users = User.includes(account_memberships: :account).order(:role, :email_address)
    end

    def new
      @user = User.new(role: "owner", active: true)
    end

    def create
      @user = User.new(user_params)
      assign_admin_managed_user_attributes(@user)

      if @user.save
        sync_account_memberships
        redirect_to admin_users_path, notice: "User added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      @user.assign_attributes(user_params)
      assign_admin_managed_user_attributes(@user)

      if @user.save
        sync_account_memberships
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
      @accounts = Account.client.ordered
    end

    def user_params
      permitted = params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
      permitted.except!(:password, :password_confirmation) if permitted[:password].blank? && @user&.persisted?
      permitted
    end

    def assign_admin_managed_user_attributes(user)
      user.role = params.dig(:user, :role) if params.dig(:user, :role).present?
      return unless params.dig(:user, :active)

      user.active = ActiveModel::Type::Boolean.new.cast(params.dig(:user, :active))
    end

    def sync_account_memberships
      selected_account_ids = Array(params.dig(:user, :account_ids)).compact_blank.map(&:to_i)

      Account.where(id: selected_account_ids).find_each do |account|
        membership = @user.account_memberships.find_or_initialize_by(account: account)
        membership.access_level = "read_only"
        membership.active = true
        membership.save!
      end

      @user.account_memberships.where.not(account_id: selected_account_ids).update_all(active: false, updated_at: Time.current)
    end
  end
end
