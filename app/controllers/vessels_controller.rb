class VesselsController < ApplicationController
  before_action :set_vessel, only: %i[show edit update destroy]

  def index
    @query = params[:q].to_s.strip
    @vessels = Asset.vessels.search(@query).includes(:account, :reminders, :service_visits).ordered
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
    @accounts = Account.order(:name)
  end

  def create
    @vessel = Asset.new(vessel_params)
    @vessel.asset_type = "vessel"

    if @vessel.save
      redirect_to vessel_path(@vessel), notice: "Vessel added."
    else
      @accounts = Account.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @accounts = Account.order(:name)
  end

  def update
    if @vessel.update(vessel_params)
      redirect_to vessel_path(@vessel), notice: "Vessel updated."
    else
      @accounts = Account.order(:name)
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
      :account_id,
      :name,
      :make,
      :model,
      :year,
      :length,
      :registration_number,
      :marina,
      :slip,
      :notes
    )
  end
end
