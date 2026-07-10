class VesselsController < ApplicationController
  before_action :require_write_access!, only: %i[new create edit update destroy]
  before_action :set_vessel, only: %i[show edit update destroy]

  def index
    @query = params[:q].to_s.strip
    @include_inactive = params[:include_inactive].present?
    @vessels = scoped_vessels.search(@query).includes(:account, :reminders, :service_visits, :documents, :binder_notes).with_attached_primary_photo.ordered
    @vessels = @vessels.active unless @include_inactive
  end

  def show
    @service_visits = @vessel.service_visits.includes(
      :performed_by_user,
      :service_visit_inspection_checks,
      service_visit_engine_readings: :asset_engine,
      service_visit_battery_checks: :asset_battery
    ).recent.limit(5)
    @documents = @vessel.documents.order(created_at: :desc).limit(6)
    @binder_notes = @vessel.binder_notes.order(created_at: :desc).limit(6)
    @overdue_reminders = @vessel.overdue_reminders.limit(4)
    @upcoming_reminders = @vessel.reminders.upcoming.limit(5)
    @completed_reminders = @vessel.reminders.completed.order(updated_at: :desc).limit(3)
    @open_follow_ups = @vessel.open_follow_up_visits.limit(3)
    @asset_batteries = @vessel.asset_batteries.ordered
    @owner_contact = @vessel.owner_contact
    @primary_contact = @vessel.primary_contact
    @last_visit = @vessel.last_visit
    @next_reminder = @vessel.next_reminder
    @binder_note = @vessel.binder_notes.new(account: @vessel.account)
  end

  def new
    @vessel = Asset.new(asset_type: "vessel")
    @accounts = scoped_accounts.active.ordered
  end

  def create
    @vessel = Asset.new(vessel_params)
    @vessel.asset_type = "vessel"
    return unless assign_vessel_account(@vessel)

    if @vessel.save
      redirect_to vessel_path(@vessel), notice: "Vessel added."
    else
      @accounts = scoped_accounts.active.ordered
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
    @vessel = scoped_vessels.includes({ account: :contacts }, primary_photo_attachment: :blob).find_by!(slug: params[:id])
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
      :active,
      :primary_photo
    )
  end

  def owner_options_for(vessel)
    scoped_accounts.where(active: true).or(scoped_accounts.where(id: vessel.account_id)).ordered
  end

  def assign_vessel_account(vessel)
    return true if vessel_account_id.blank?

    unless can_manage_vessel_accounts?
      deny_access!
      return false
    end

    vessel.account = scoped_accounts.find(vessel_account_id)
    true
  end

  def vessel_account_id
    params.require(:asset)[:account_id]
  end

  def can_manage_vessel_accounts?
    can_manage_records?
  end
end
