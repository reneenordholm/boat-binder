class VesselsController < ApplicationController
  before_action :set_vessel, only: %i[show edit update destroy]

  def index
    @query = params[:q].to_s.strip
    @include_inactive = params[:include_inactive].present?
    @vessels = Asset.vessels.search(@query).includes(:account, :reminders, :service_visits).ordered
    @vessels = @vessels.active unless @include_inactive
  end

  def show
    @service_visits = @vessel.service_visits.includes(:performed_by_user).recent.limit(5)
    @documents = @vessel.documents.order(created_at: :desc).limit(6)
    @binder_notes = @vessel.binder_notes.order(created_at: :desc).limit(6)
    @overdue_reminders = @vessel.overdue_reminders.limit(4)
    @upcoming_reminders = @vessel.reminders.upcoming.limit(5)
    @completed_reminders = @vessel.reminders.completed.order(updated_at: :desc).limit(3)
    @open_follow_ups = @vessel.open_follow_up_visits.limit(3)
    @owner_contact = @vessel.owner_contact
    @primary_contact = @vessel.primary_contact
    @last_visit = @vessel.last_visit
    @next_reminder = @vessel.next_reminder
    @binder_note = @vessel.binder_notes.new(account: @vessel.account)
  end

  def new
    @vessel = Asset.new(asset_type: "vessel")
    @accounts = Account.active.ordered
  end

  def create
    @vessel = Asset.new(vessel_params)
    @vessel.asset_type = "vessel"
    return unless assign_vessel_account(@vessel)

    if @vessel.save
      redirect_to vessel_path(@vessel), notice: "Vessel added."
    else
      @accounts = Account.active.ordered
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @accounts = owner_options_for(@vessel)
  end

  def update
    return unless assign_vessel_account(@vessel)

    if @vessel.update(vessel_params)
      redirect_to vessel_path(@vessel), notice: "Vessel updated."
    else
      @accounts = owner_options_for(@vessel)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @vessel.destroy!
    redirect_to vessels_path, notice: "Vessel removed."
  end

  private

  def set_vessel
    @vessel = Asset.vessels.includes(account: :contacts).find_by!(slug: params[:id])
  end

  def vessel_params
    params.require(:asset).permit(
      :name,
      :make,
      :model,
      :year,
      :length,
      :registration_number,
      :marina,
      :slip,
      :notes,
      :active
    )
  end

  def owner_options_for(vessel)
    Account.where(active: true).or(Account.where(id: vessel.account_id)).ordered
  end

  def assign_vessel_account(vessel)
    return true if vessel_account_id.blank?

    unless can_manage_vessel_accounts?
      head :forbidden
      return false
    end

    vessel.account = Account.find(vessel_account_id)
    true
  end

  def vessel_account_id
    params.require(:asset)[:account_id]
  end

  def can_manage_vessel_accounts?
    Current.user&.role.in?(%w[admin captain])
  end
end
