require "test_helper"

class BillingWebhookEventTest < ActiveSupport::TestCase
  test "validates supported providers and statuses" do
    event = BillingWebhookEvent.new(
      provider: "stripe",
      external_event_id: "evt_valid",
      event_type: "customer.subscription.updated",
      livemode: false,
      status: "received"
    )

    assert event.valid?

    event.provider = "paypal"
    assert_not event.valid?
    assert_includes event.errors[:provider], "is not included in the list"

    event.provider = "stripe"
    event.status = "queued"
    assert_not event.valid?
    assert_includes event.errors[:status], "is not included in the list"
  end

  test "external event id uniqueness is scoped to provider" do
    BillingWebhookEvent.create!(
      provider: "stripe",
      external_event_id: "evt_same_id",
      event_type: "invoice.paid",
      livemode: false,
      status: "ignored"
    )

    duplicate = BillingWebhookEvent.new(
      provider: "stripe",
      external_event_id: "evt_same_id",
      event_type: "invoice.paid",
      livemode: false,
      status: "received"
    )
    other_provider = BillingWebhookEvent.new(
      provider: "local",
      external_event_id: "evt_same_id",
      event_type: "local.test",
      livemode: false,
      status: "received"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_event_id], "has already been taken"
    assert other_provider.valid?
  end

  test "database enforces idempotency and domain constraints" do
    timestamp = Time.current
    attributes = {
      provider: "stripe",
      external_event_id: "evt_database_duplicate",
      event_type: "invoice.paid",
      livemode: false,
      status: "received",
      created_at: timestamp,
      updated_at: timestamp
    }

    BillingWebhookEvent.insert_all!([ attributes ])

    assert_raises(ActiveRecord::RecordNotUnique) do
      BillingWebhookEvent.insert_all!([ attributes.merge(created_at: Time.current, updated_at: Time.current) ])
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      BillingWebhookEvent.insert_all!([
        attributes.merge(
          provider: "paypal",
          external_event_id: "evt_invalid_provider",
          created_at: Time.current,
          updated_at: Time.current
        )
      ])
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      BillingWebhookEvent.insert_all!([
        attributes.merge(
          status: "queued",
          external_event_id: "evt_invalid_status",
          created_at: Time.current,
          updated_at: Time.current
        )
      ])
    end
  end

  test "database indexes and constraints are present" do
    indexes = ActiveRecord::Base.connection.indexes(:billing_webhook_events)
    idempotency_index = indexes.find { |index| index.columns == %w[provider external_event_id] }

    assert idempotency_index
    assert idempotency_index.unique

    constraints = ActiveRecord::Base.connection.check_constraints(:billing_webhook_events)
    provider_constraint = constraints.find { |constraint| constraint.name == "chk_billing_webhook_events_provider" }
    status_constraint = constraints.find { |constraint| constraint.name == "chk_billing_webhook_events_status" }

    assert provider_constraint
    assert_match(/local/, provider_constraint.expression)
    assert_match(/stripe/, provider_constraint.expression)
    assert status_constraint
    assert_match(/received/, status_constraint.expression)
    assert_match(/ignored/, status_constraint.expression)
    assert_match(/failed/, status_constraint.expression)
  end

  test "receipt metadata does not store raw payloads or secrets" do
    assert_not_includes BillingWebhookEvent.column_names, "raw_payload"
    assert_not_includes BillingWebhookEvent.column_names, "payload"
    assert_not_includes BillingWebhookEvent.column_names, "secret"
    assert_not_includes BillingWebhookEvent.column_names, "api_key"
  end

  test "receipt lifecycle transitions keep state consistent" do
    event = BillingWebhookEvent.create!(
      provider: "stripe",
      external_event_id: "evt_lifecycle",
      event_type: "invoice.payment_failed",
      livemode: false,
      status: "received"
    )

    event.mark_failed!(error_code: "RuntimeError")
    assert event.failed?
    assert_nil event.processed_at
    assert event.failed_at.present?
    assert_equal "RuntimeError", event.error_code

    event.mark_ignored!
    assert event.ignored?
    assert event.completed?
    assert event.processed_at.present?
    assert_nil event.failed_at
    assert_nil event.error_code

    event.mark_failed!(error_code: "TimeoutError")
    event.mark_processed!
    assert event.processed?
    assert event.completed?
    assert event.processed_at.present?
    assert_nil event.failed_at
    assert_nil event.error_code
  end
end
