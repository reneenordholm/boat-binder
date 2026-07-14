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

  def ignored?
    status == "ignored"
  end

  def failed?
    status == "failed"
  end
end
