require "test_helper"

class StripeWebhookTest < ActionDispatch::IntegrationTest
  WEBHOOK_SECRET = "whsec_test_secret"

  setup do
    @previous_webhook_secret = Rails.configuration.x.stripe.webhook_secret
    Rails.configuration.x.stripe.webhook_secret = WEBHOOK_SECRET
  end

  teardown do
    Rails.configuration.x.stripe.webhook_secret = @previous_webhook_secret
  end

  test "test environment initializes without real Stripe credentials" do
    assert_nothing_raised do
      Billing::StripeConfiguration.secret_key
      Billing::StripeConfiguration.publishable_key
      Billing::StripeConfiguration.webhook_secret
    end
  end

  test "webhook route accepts post without authentication and rejects get" do
    assert_difference -> { BillingWebhookEvent.count }, 1 do
      post_signed_event(event_id: "evt_route_post")
    end
    assert_response :success

    get webhooks_stripe_path
    assert_response :not_found
  end

  test "webhook endpoint is not exposed in user navigation" do
    user = create_user(email: "stripe-nav-admin@example.test", role: "admin")
    sign_in_as(user)

    get root_path
    assert_response :success
    assert_not_includes response.body, "/webhooks/stripe"
  end

  test "normal authenticated requests do not invoke Stripe webhook verification" do
    user = create_user(email: "stripe-normal-request@example.test", role: "admin")
    sign_in_as(user)

    with_stripe_webhook_verification_failure do
      get root_path
    end

    assert_response :success
  end

  test "only Stripe webhook controller skips csrf verification" do
    assert csrf_skipped_for_action?(Webhooks::StripeController, :create)
    assert_not csrf_skipped_for_action?(SessionsController, :create)
    assert_not csrf_skipped_for_action?(VesselsController, :create)
  end

  test "valid signed subscription event is accepted and recorded as ignored" do
    assert_difference -> { BillingWebhookEvent.count }, 1 do
      post_signed_event(
        event_id: "evt_subscription_updated",
        event_type: "customer.subscription.updated",
        livemode: true,
        api_version: "2026-07-01"
      )
    end

    assert_response :success
    receipt = BillingWebhookEvent.find_by!(provider: "stripe", external_event_id: "evt_subscription_updated")
    assert_equal "customer.subscription.updated", receipt.event_type
    assert receipt.livemode?
    assert_equal "2026-07-01", receipt.api_version
    assert_equal "ignored", receipt.status
    assert receipt.processed_at.present?
  end

  test "valid unknown event is safely recorded and ignored" do
    post_signed_event(event_id: "evt_unknown", event_type: "customer.created")
    assert_response :success

    receipt = BillingWebhookEvent.find_by!(provider: "stripe", external_event_id: "evt_unknown")
    assert_equal "customer.created", receipt.event_type
    assert_equal "ignored", receipt.status
  end

  test "duplicate valid delivery returns success without a second receipt" do
    payload = stripe_event_payload(event_id: "evt_duplicate", event_type: "invoice.paid")
    headers = stripe_signature_headers(payload)

    assert_difference -> { BillingWebhookEvent.count }, 1 do
      post webhooks_stripe_path, params: payload, headers: headers
    end
    assert_response :success

    assert_no_difference -> { BillingWebhookEvent.count } do
      post webhooks_stripe_path, params: payload, headers: headers
    end
    assert_response :success
  end

  test "missing webhook secret fails safely without exposing secrets" do
    Rails.configuration.x.stripe.webhook_secret = nil

    post webhooks_stripe_path,
      params: stripe_event_payload(event_id: "evt_missing_secret"),
      headers: stripe_signature_headers(stripe_event_payload(event_id: "evt_missing_secret"))

    assert_response :bad_request
    assert_equal "", response.body
    assert_not BillingWebhookEvent.exists?(external_event_id: "evt_missing_secret")
  end

  test "missing and invalid signatures are rejected" do
    payload = stripe_event_payload(event_id: "evt_bad_signature")

    assert_no_difference -> { BillingWebhookEvent.count } do
      post webhooks_stripe_path, params: payload, headers: { "CONTENT_TYPE" => "application/json" }
    end
    assert_response :bad_request

    assert_no_difference -> { BillingWebhookEvent.count } do
      post webhooks_stripe_path,
        params: payload,
        headers: stripe_signature_headers(payload, secret: "wrong_secret")
    end
    assert_response :bad_request
  end

  test "malformed JSON with a valid signature is rejected" do
    payload = "{not-json"

    assert_no_difference -> { BillingWebhookEvent.count } do
      post webhooks_stripe_path, params: payload, headers: stripe_signature_headers(payload)
    end
    assert_response :bad_request
  end

  test "modified payload fails signature verification because raw body is used" do
    signed_payload = stripe_event_payload(event_id: "evt_original")
    modified_payload = stripe_event_payload(event_id: "evt_modified")

    assert_no_difference -> { BillingWebhookEvent.count } do
      post webhooks_stripe_path,
        params: modified_payload,
        headers: stripe_signature_headers(signed_payload)
    end
    assert_response :bad_request
  end

  test "dispatcher failure returns retryable error and records sanitized failure" do
    with_processor_failure do
      post_signed_event(event_id: "evt_dispatch_failure", event_type: "invoice.payment_failed")
    end

    assert_response :internal_server_error
    receipt = BillingWebhookEvent.find_by!(provider: "stripe", external_event_id: "evt_dispatch_failure")
    assert_equal "failed", receipt.status
    assert_equal "RuntimeError", receipt.error_code
    assert receipt.failed_at.present?
    assert_not_includes response.body, "synthetic failure"
  end

  test "webhook events do not change local subscription lifecycle state in this phase" do
    account = create_account(name: "Stripe Foundation Owner")
    original_attributes = account.subscription.attributes.slice("plan", "status", "provider", "external_customer_id", "external_subscription_id")

    post_signed_event(event_id: "evt_no_subscription_sync", event_type: "customer.subscription.deleted")
    assert_response :success

    assert_equal original_attributes, account.subscription.reload.attributes.slice("plan", "status", "provider", "external_customer_id", "external_subscription_id")
  end

  private

  def post_signed_event(event_id:, event_type: "customer.subscription.updated", livemode: false, api_version: "2026-07-01")
    payload = stripe_event_payload(
      event_id: event_id,
      event_type: event_type,
      livemode: livemode,
      api_version: api_version
    )
    post webhooks_stripe_path, params: payload, headers: stripe_signature_headers(payload)
  end

  def stripe_event_payload(event_id:, event_type: "customer.subscription.updated", livemode: false, api_version: "2026-07-01")
    JSON.generate(
      id: event_id,
      object: "event",
      type: event_type,
      livemode: livemode,
      api_version: api_version,
      data: {
        object: {
          id: "sub_test",
          object: "subscription"
        }
      }
    )
  end

  def stripe_signature_headers(payload, secret: WEBHOOK_SECRET)
    timestamp = Time.current
    signature = Stripe::Webhook::Signature.compute_signature(timestamp, payload, secret)
    {
      "CONTENT_TYPE" => "application/json",
      "Stripe-Signature" => Stripe::Webhook::Signature.generate_header(timestamp, signature)
    }
  end

  def csrf_skipped_for_action?(controller, action)
    callback = controller._process_action_callbacks.find do |candidate|
      candidate.kind == :before && candidate.filter == :verify_authenticity_token
    end
    return false unless callback

    callback.instance_variable_get(:@unless).any? do |condition|
      condition.instance_variable_get(:@actions)&.include?(action.to_s)
    end
  end

  def with_processor_failure
    original_method = Billing::StripeWebhookProcessor.instance_method(:process_event!)
    Billing::StripeWebhookProcessor.define_method(:process_event!) do |_billing_webhook_event|
      raise "synthetic failure"
    end
    Billing::StripeWebhookProcessor.send(:private, :process_event!)

    yield
  ensure
    Billing::StripeWebhookProcessor.define_method(:process_event!, original_method)
    Billing::StripeWebhookProcessor.send(:private, :process_event!)
  end

  def with_stripe_webhook_verification_failure
    original_method = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) do |*|
      raise "Stripe verification should not run"
    end

    yield
  ensure
    Stripe::Webhook.define_singleton_method(:construct_event, original_method)
  end
end
