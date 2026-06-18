class DashboardController < ApplicationController
  def index
    @vessels = scoped_vessels.active.includes(:account, :reminders, :service_visits).ordered
    @upcoming_reminders = scoped_reminders.includes(asset: :account).upcoming.limit(6)
    @recent_service_visits = scoped_service_visits.includes(:asset, :performed_by_user).recent.limit(5)
    @follow_up_items = scoped_service_visits.includes(:asset).where(follow_up_needed: true).recent.limit(5)
    @recent_documents = scoped_documents.includes(:asset, :account).order(created_at: :desc).limit(5)
  end
end
