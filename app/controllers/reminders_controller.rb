class RemindersController < ApplicationController
  before_action :set_reminder, only: %i[edit update]
  before_action :set_form_collections, only: %i[new create edit update]

  def index
    @reminders = Reminder.includes(asset: :account).order(status: :desc, due_date: :asc)
  end

  def new
    @reminder = Reminder.new(due_date: Date.current, status: "pending", reminder_type: "maintenance")
  end

  def create
    @reminder = Reminder.new(reminder_params)
    @reminder.status = "pending" if @reminder.status.blank?

    if @reminder.save
      redirect_to reminders_path, notice: "Reminder added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if params[:status_action] == "complete"
      @reminder.complete!
      redirect_back fallback_location: reminders_path, notice: "Reminder completed."
    elsif params[:status_action] == "reopen"
      @reminder.reopen!
      redirect_back fallback_location: reminders_path, notice: "Reminder reopened."
    elsif @reminder.update(reminder_params)
      redirect_to reminders_path, notice: "Reminder updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_reminder
    @reminder = Reminder.find(params[:id])
  end

  def set_form_collections
    @accounts = Account.active.includes(:assets).ordered
    @vessels = Asset.vessels.active.includes(:account).ordered
  end

  def reminder_params
    params.require(:reminder).permit(:asset_id, :title, :due_date, :reminder_type, :status)
  end
end
