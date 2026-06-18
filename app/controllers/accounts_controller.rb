class AccountsController < ApplicationController
  before_action :require_write_access!, only: %i[new create edit update]
  before_action :set_account, only: %i[show edit update]

  def index
    @include_inactive = params[:include_inactive].present?
    @accounts = scoped_accounts.includes(:contacts, :assets).ordered
    @accounts = @accounts.active unless @include_inactive
  end

  def show
    @contacts = @account.contacts.order(:role, :name)
    @vessels = @account.assets.vessels.ordered
    @documents = @account.documents.includes(:asset).order(created_at: :desc).limit(6)
  end

  def new
    @account = Account.new(account_type: "client", active: true)
    @contact = @account.contacts.new(role: "Owner")
  end

  def create
    @account = Account.new(account_params)
    @account.account_type = "client"
    @contact = @account.contacts.new(contact_params.merge(role: "Owner"))

    if @account.save
      redirect_to owner_path(@account), notice: "Owner added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @contact = @account.primary_contact || @account.contacts.new(role: "Owner")
  end

  def update
    @contact = @account.primary_contact || @account.contacts.new(role: "Owner")

    Account.transaction do
      @account.update!(account_params)
      @contact.update!(contact_params.merge(role: @contact.role.presence || "Owner"))
    end

    redirect_to owner_path(@account), notice: "Owner updated."
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  private

  def set_account
    @account = scoped_accounts.find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name, :notes, :active)
  end

  def contact_params
    params.fetch(:contact, {}).permit(:name, :email, :phone)
  end
end
