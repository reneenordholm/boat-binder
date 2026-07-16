class BillingWebhookEvent < ApplicationRecord
  PROVIDERS = Subscription::PROVIDERS
  STRIPE_PROVIDER = Subscription::STRIPE_PROVIDER
  STATUSES = %w[received processed ignored failed].freeze

  validates :provider, inclusion: { in: PROVIDERS }
  validates :external_event_id, presence: true, uniqueness: { scope: :provider }
  validates :event_type, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :livemode, inclusion: { in: [ true, false ] }

  scope :stripe, -> { where(provider: STRIPE_PROVIDER) }

  def completed?
    processed? || ignored?
  end

  def processed?
    status == "processed"
  end

  def ignored?
    status == "ignored"
  end

  def failed?
    status == "failed"
  end

  def mark_ignored!
    update!(
      status: "ignored",
      processed_at: Time.current,
      failed_at: nil,
      error_code: nil
    )
  end

  def mark_processed!
    update!(
      status: "processed",
      processed_at: Time.current,
      failed_at: nil,
      error_code: nil
    )
  end

  def mark_failed!(error_code:)
    update!(
      status: "failed",
      processed_at: nil,
      failed_at: Time.current,
      error_code: error_code
    )
  end
end
