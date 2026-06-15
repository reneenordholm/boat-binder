class VesselsController < ApplicationController
  def index
    @vessels = Asset.vessels.includes(:account, :reminders, :service_visits).ordered
  end

  def show
    @vessel = Asset.vessels.includes(account: :contacts).find(params[:id])
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
end
