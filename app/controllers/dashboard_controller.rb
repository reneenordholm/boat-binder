class DashboardController < ApplicationController
  def index
    @vessels = Asset.vessels.active.includes(:account, :reminders, :service_visits).ordered
    @upcoming_reminders = Reminder.includes(asset: :account).upcoming.limit(6)
    @recent_service_visits = ServiceVisit.includes(:asset, :performed_by_user).recent.limit(5)
    @follow_up_items = ServiceVisit.includes(:asset).where(follow_up_needed: true).recent.limit(5)
    @recent_documents = Document.includes(:asset, :account).order(created_at: :desc).limit(5)
  end
end
