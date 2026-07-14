module Billing
  class StripeWebhookProcessor
    STRIPE_PROVIDER = BillingWebhookEvent::STRIPE_PROVIDER
    IGNORED_EVENT_TYPES = %w[
      checkout.session.completed
      customer.subscription.created
      customer.subscription.deleted
      customer.subscription.updated
      invoice.paid
      invoice.payment_failed
    ].freeze

    Result = Struct.new(:success?, :billing_webhook_event, :duplicate?, keyword_init: true)

    def self.call(event)
      new(event).call
    end

    def initialize(event)
      @event = event
    end

    def call
      billing_webhook_event = persist_event_receipt
      return success_result(billing_webhook_event, duplicate: true) unless @receipt_created

      process_event!(billing_webhook_event)
      success_result(billing_webhook_event)
    rescue ActiveRecord::RecordNotUnique
      success_result(find_existing_receipt, duplicate: true)
    rescue StandardError => error
      mark_failed(error)
      Rails.logger.error(
        "Stripe webhook processing failed provider=stripe event_id=#{event_id.inspect} " \
        "event_type=#{event_type.inspect} error=#{error.class.name}"
      )
      Result.new(success?: false, billing_webhook_event: @billing_webhook_event, duplicate?: false)
    end

    private

    attr_reader :event

    def persist_event_receipt
      existing_receipt = BillingWebhookEvent.find_by(provider: STRIPE_PROVIDER, external_event_id: event_id)
      if existing_receipt
        @receipt_created = false
        return @billing_webhook_event = existing_receipt
      end

      @receipt_created = true
      @billing_webhook_event = BillingWebhookEvent.create!(
        provider: STRIPE_PROVIDER,
        external_event_id: event_id,
        event_type: event_type,
        livemode: livemode,
        api_version: api_version,
        status: "received"
      )
    end

    def process_event!(billing_webhook_event)
      ignore_reason = IGNORED_EVENT_TYPES.include?(event_type) ? "deferred" : "unknown"
      billing_webhook_event.update!(status: "ignored", processed_at: Time.current)

      Rails.logger.info(
        "Stripe webhook ignored reason=#{ignore_reason} event_id=#{event_id} " \
        "event_type=#{event_type} livemode=#{livemode}"
      )
    end

    def mark_failed(error)
      return unless @billing_webhook_event&.persisted?

      @billing_webhook_event.update!(
        status: "failed",
        failed_at: Time.current,
        error_code: error.class.name.demodulize
      )
    rescue StandardError => update_error
      Rails.logger.error(
        "Stripe webhook failure status update failed provider=stripe event_id=#{event_id.inspect} " \
        "error=#{update_error.class.name}"
      )
    end

    def find_existing_receipt
      BillingWebhookEvent.find_by!(provider: STRIPE_PROVIDER, external_event_id: event_id)
    end

    def success_result(billing_webhook_event, duplicate: false)
      Result.new(success?: true, billing_webhook_event: billing_webhook_event, duplicate?: duplicate)
    end

    def event_id
      event.id
    end

    def event_type
      event.type
    end

    def livemode
      event.livemode == true
    end

    def api_version
      event.api_version
    end
  end
end
