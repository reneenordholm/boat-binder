module AccountTimeZoneContext
  extend ActiveSupport::Concern

  included do
    if respond_to?(:helper_method)
      helper_method :account_time_zone, :account_today, :account_local_time, :with_account_time_zone
    end
  end

  def account_time_zone(account)
    Time.find_zone(account&.time_zone.presence) || Time.zone
  end

  def with_account_time_zone(account, &block)
    Time.use_zone(account_time_zone(account), &block)
  end

  def account_today(account)
    with_account_time_zone(account) { Time.zone.today }
  end

  def account_local_time(value, account)
    return if value.blank?
    return value if date_only?(value)

    value.in_time_zone(account_time_zone(account))
  end

  private

  def date_only?(value)
    value.is_a?(Date) && !value.respond_to?(:hour)
  end
end
