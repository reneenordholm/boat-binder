module Authorization
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :admin_user?, :internal_user?, :owner_user?, :can_manage_records?
  end

  private

  def current_user
    Current.user
  end

  def admin_user?
    current_user&.admin?
  end

  def internal_user?
    current_user&.internal?
  end

  def owner_user?
    current_user&.owner?
  end

  def can_manage_records?
    internal_user?
  end

  def require_admin!
    head :forbidden unless admin_user?
  end

  def require_internal!
    head :forbidden unless internal_user?
  end

  def require_write_access!
    head :forbidden unless can_manage_records?
  end

  def ensure_active_user!
    return unless authenticated?
    return if current_user&.active?

    terminate_session
    redirect_to new_session_path, alert: "This user account is inactive."
  end

  def scoped_accounts
    return Account.all if internal_user?

    Account.where(id: current_user.active_account_ids)
  end

  def scoped_assets
    return Asset.all if internal_user?

    Asset.where(account_id: current_user.active_account_ids)
  end

  def scoped_vessels
    scoped_assets.vessels
  end

  def scoped_documents
    return Document.all if internal_user?

    Document.where(account_id: current_user.active_account_ids)
  end

  def scoped_reminders
    return Reminder.all if internal_user?

    Reminder.joins(:asset).where(assets: { account_id: current_user.active_account_ids })
  end

  def scoped_service_visits
    return ServiceVisit.all if internal_user?

    ServiceVisit.joins(:asset).where(assets: { account_id: current_user.active_account_ids })
  end

  def scoped_binder_notes
    return BinderNote.all if internal_user?

    BinderNote.where(account_id: current_user.active_account_ids)
  end
end
