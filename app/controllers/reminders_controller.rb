class RemindersController < ApplicationController
  def index
    @reminders = Reminder.includes(asset: :account).order(status: :desc, due_date: :asc)
  end

  def update
    @reminder = Reminder.find(params[:id])
    @reminder.complete!
    redirect_back fallback_location: reminders_path, notice: "Reminder completed."
  end
end
