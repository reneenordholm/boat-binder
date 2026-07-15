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
    assert_recognizes(
      { controller: "webhooks/stripe", action: "create" },
      { path: "/webhooks/stripe", method: :post }
    )

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

  test "normal browser-facing posts still require csrf protection" do
    with_forgery_protection do
      post session_path, params: {
        email_address: "captain@example.test",
        password: "password"
      }
    end

    assert_response :unprocessable_entity
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
    assert_equal [ "create" ], csrf_skip_actions(Webhooks::StripeController)
    assert_not csrf_skipped_for_action?(SessionsController, :create)
    assert_not csrf_skipped_for_action?(VesselsController, :create)
  end

  test "valid signed subscription event is accepted and recorded as ignored" do
    dispatched_event_ids = []

    assert_difference -> { BillingWebhookEvent.count }, 1 do
      with_processor_call_spy(dispatched_event_ids) do
        post_signed_event(
          event_id: "evt_subscription_updated",
          event_type: "customer.subscription.updated",
          livemode: true,
          api_version: "2026-07-01"
        )
      end
    end

    assert_response :success
    assert_equal [ "evt_subscription_updated" ], dispatched_event_ids
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
    process_count = 0

    assert_difference -> { BillingWebhookEvent.count }, 1 do
      with_process_event_count(process_count) do |counter|
        post webhooks_stripe_path, params: payload, headers: headers
        process_count = counter.call
      end
    end
    assert_response :success
    assert_equal 1, process_count

    assert_no_difference -> { BillingWebhookEvent.count } do
      with_process_event_count(process_count) do |counter|
        post webhooks_stripe_path, params: payload, headers: headers
        process_count = counter.call
      end
    end
    assert_response :success
    assert_equal 1, process_count
  end

  test "missing webhook secret fails safely without exposing secrets" do
    Rails.configuration.x.stripe.webhook_secret = nil

    with_processor_call_failure do
      post webhooks_stripe_path,
        params: stripe_event_payload(event_id: "evt_missing_secret"),
        headers: stripe_signature_headers(stripe_event_payload(event_id: "evt_missing_secret"))
    end

    assert_response :bad_request
    assert_equal "", response.body
    assert_not BillingWebhookEvent.exists?(external_event_id: "evt_missing_secret")
  end

  test "missing and invalid signatures are rejected" do
    payload = stripe_event_payload(event_id: "evt_bad_signature")

    assert_no_difference -> { BillingWebhookEvent.count } do
      with_processor_call_failure do
        post webhooks_stripe_path, params: payload, headers: { "CONTENT_TYPE" => "application/json" }
      end
    end
    assert_response :bad_request

    assert_no_difference -> { BillingWebhookEvent.count } do
      with_processor_call_failure do
        post webhooks_stripe_path,
          params: payload,
          headers: stripe_signature_headers(payload, secret: "wrong_secret")
      end
    end
    assert_response :bad_request
  end

  test "malformed JSON with a valid signature is rejected" do
    payload = "{not-json"

    assert_no_difference -> { BillingWebhookEvent.count } do
      with_processor_call_failure do
        post webhooks_stripe_path, params: payload, headers: stripe_signature_headers(payload)
      end
    end
    assert_response :bad_request
  end

  test "modified payload fails signature verification because raw body is used" do
    signed_payload = stripe_event_payload(event_id: "evt_original")
    modified_payload = stripe_event_payload(event_id: "evt_modified")

    assert_no_difference -> { BillingWebhookEvent.count } do
      with_processor_call_failure do
        post webhooks_stripe_path,
          params: modified_payload,
          headers: stripe_signature_headers(signed_payload)
      end
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
    csrf_skip_actions(controller).include?(action.to_s)
  end

  def csrf_skip_actions(controller)
    callback = controller._process_action_callbacks.find do |candidate|
      candidate.kind == :before && candidate.filter == :verify_authenticity_token
    end
    return [] unless callback

    callback.instance_variable_get(:@unless).filter_map do |condition|
      condition.instance_variable_get(:@actions)&.to_a
    end.flatten.sort
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

  def with_processor_call_failure
    original_method = Billing::StripeWebhookProcessor.method(:call)
    Billing::StripeWebhookProcessor.define_singleton_method(:call) do |_event|
      raise "processor should not run"
    end

    yield
  ensure
    Billing::StripeWebhookProcessor.define_singleton_method(:call, original_method)
  end

  def with_processor_call_spy(dispatched_event_ids)
    original_method = Billing::StripeWebhookProcessor.method(:call)
    Billing::StripeWebhookProcessor.define_singleton_method(:call) do |event|
      dispatched_event_ids << event.id
      original_method.call(event)
    end

    yield
  ensure
    Billing::StripeWebhookProcessor.define_singleton_method(:call, original_method)
  end

  def with_process_event_count(initial_count)
    count = initial_count
    original_method = Billing::StripeWebhookProcessor.instance_method(:process_event!)
    Billing::StripeWebhookProcessor.define_method(:process_event!) do |billing_webhook_event|
      count += 1
      original_method.bind_call(self, billing_webhook_event)
    end
    Billing::StripeWebhookProcessor.send(:private, :process_event!)

    yield -> { count }
  ensure
    Billing::StripeWebhookProcessor.define_method(:process_event!, original_method)
    Billing::StripeWebhookProcessor.send(:private, :process_event!)
  end

  def with_forgery_protection
    previous_application_value = ApplicationController.allow_forgery_protection
    previous_base_value = ActionController::Base.allow_forgery_protection
    ApplicationController.allow_forgery_protection = true
    ActionController::Base.allow_forgery_protection = true

    yield
  ensure
    ApplicationController.allow_forgery_protection = previous_application_value
    ActionController::Base.allow_forgery_protection = previous_base_value
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
