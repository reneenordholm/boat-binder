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

  test "webhook parameter logs filter billing payload and do not duplicate stripe wrapper" do
    data_object = {
      id: "in_sensitive",
      object: "invoice",
      customer: "cus_sensitive",
      customer_email: "owner@example.test",
      hosted_invoice_url: "https://invoice.stripe.com/i/acct_sensitive/test_sensitive",
      invoice_pdf: "https://pay.stripe.com/invoice/acct_sensitive/pdf_sensitive",
      payment_intent: "pi_sensitive",
      lines: {
        data: [
          {
            id: "il_sensitive",
            description: "Private invoice line",
            amount: 49900
          }
        ]
      }
    }
    payload = stripe_event_payload(
      event_id: "evt_payment_succeeded",
      event_type: "invoice.payment_succeeded",
      livemode: true,
      data_object: data_object
    )
    log_output = capture_rails_logs do
      post webhooks_stripe_path, params: payload, headers: stripe_signature_headers(payload)
    end

    assert_response :success

    filtered_parameters = request.filtered_parameters
    assert_equal "[FILTERED]", filtered_parameters["data"]
    assert_not filtered_parameters.key?("stripe")

    assert_includes log_output, "Stripe webhook ignored"
    assert_includes log_output, "reason=deferred"
    assert_includes log_output, "event_id=evt_payment_succeeded"
    assert_includes log_output, "event_type=invoice.payment_succeeded"
    assert_includes log_output, "livemode=true"
    assert_not_includes log_output, "owner@example.test"
    assert_not_includes log_output, "https://invoice.stripe.com"
    assert_not_includes log_output, "https://pay.stripe.com"
    assert_not_includes log_output, "Private invoice line"
    assert_not_includes log_output, "pi_sensitive"
    assert_not_includes log_output, "\"stripe\""

    receipt = BillingWebhookEvent.find_by!(provider: "stripe", external_event_id: "evt_payment_succeeded")
    assert_equal "invoice.payment_succeeded", receipt.event_type
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

  test "failed event receipt is retried and clears failure metadata after success" do
    payload = stripe_event_payload(event_id: "evt_retry_after_failure", event_type: "invoice.payment_failed")
    headers = stripe_signature_headers(payload)

    assert_difference -> { BillingWebhookEvent.count }, 1 do
      with_processor_failure do
        post webhooks_stripe_path, params: payload, headers: headers
      end
    end
    assert_response :internal_server_error

    receipt = BillingWebhookEvent.find_by!(provider: "stripe", external_event_id: "evt_retry_after_failure")
    assert_equal "failed", receipt.status
    assert receipt.failed_at.present?
    assert_equal "RuntimeError", receipt.error_code
    assert_nil receipt.processed_at
    assert_not_includes response.body, "synthetic failure"

    process_count = 0
    assert_no_difference -> { BillingWebhookEvent.count } do
      with_process_event_count(process_count) do |counter|
        post webhooks_stripe_path, params: payload, headers: headers
        process_count = counter.call
      end
    end

    assert_response :success
    assert_equal 1, process_count
    receipt.reload
    assert_equal "ignored", receipt.status
    assert receipt.processed_at.present?
    assert_nil receipt.failed_at
    assert_nil receipt.error_code
  end

  test "failed event receipt remains retryable after repeated failures" do
    payload = stripe_event_payload(event_id: "evt_repeated_failure", event_type: "invoice.payment_failed")
    headers = stripe_signature_headers(payload)
    failure_count = 0

    assert_difference -> { BillingWebhookEvent.count }, 1 do
      with_processor_failure_count(failure_count) do |counter|
        post webhooks_stripe_path, params: payload, headers: headers
        failure_count = counter.call
      end
    end
    assert_response :internal_server_error

    receipt = BillingWebhookEvent.find_by!(provider: "stripe", external_event_id: "evt_repeated_failure")
    first_failed_at = receipt.failed_at
    assert_equal "failed", receipt.status
    assert_equal "RuntimeError", receipt.error_code
    assert_nil receipt.processed_at

    assert_no_difference -> { BillingWebhookEvent.count } do
      with_processor_failure_count(failure_count) do |counter|
        post webhooks_stripe_path, params: payload, headers: headers
        failure_count = counter.call
      end
    end

    assert_response :internal_server_error
    assert_equal 2, failure_count
    receipt.reload
    assert_equal "failed", receipt.status
    assert_operator receipt.failed_at, :>=, first_failed_at
    assert_equal "RuntimeError", receipt.error_code
    assert_nil receipt.processed_at
  end

  test "completed processed receipt is acknowledged without dispatching again" do
    processed_at = 1.hour.ago
    BillingWebhookEvent.create!(
      provider: "stripe",
      external_event_id: "evt_processed_duplicate",
      event_type: "invoice.paid",
      livemode: false,
      status: "processed",
      processed_at: processed_at
    )
    payload = stripe_event_payload(event_id: "evt_processed_duplicate", event_type: "invoice.paid")

    assert_no_difference -> { BillingWebhookEvent.count } do
      with_processor_failure do
        post webhooks_stripe_path, params: payload, headers: stripe_signature_headers(payload)
      end
    end

    assert_response :success
    receipt = BillingWebhookEvent.find_by!(provider: "stripe", external_event_id: "evt_processed_duplicate")
    assert_equal "processed", receipt.status
    assert_equal processed_at.to_i, receipt.processed_at.to_i
    assert_nil receipt.failed_at
    assert_nil receipt.error_code
  end

  test "record not unique recovery acknowledges completed receipts without dispatch" do
    BillingWebhookEvent.create!(
      provider: "stripe",
      external_event_id: "evt_race_completed",
      event_type: "invoice.paid",
      livemode: false,
      status: "ignored",
      processed_at: 1.hour.ago
    )
    payload = stripe_event_payload(event_id: "evt_race_completed", event_type: "invoice.paid")

    assert_no_difference -> { BillingWebhookEvent.count } do
      with_receipt_create_race do
        with_processor_failure do
          post webhooks_stripe_path, params: payload, headers: stripe_signature_headers(payload)
        end
      end
    end

    assert_response :success
  end

  test "record not unique recovery retries failed receipts" do
    BillingWebhookEvent.create!(
      provider: "stripe",
      external_event_id: "evt_race_failed",
      event_type: "invoice.payment_failed",
      livemode: false,
      status: "failed",
      failed_at: 1.hour.ago,
      error_code: "RuntimeError"
    )
    payload = stripe_event_payload(event_id: "evt_race_failed", event_type: "invoice.payment_failed")
    process_count = 0

    assert_no_difference -> { BillingWebhookEvent.count } do
      with_receipt_create_race do
        with_process_event_count(process_count) do |counter|
          post webhooks_stripe_path, params: payload, headers: stripe_signature_headers(payload)
          process_count = counter.call
        end
      end
    end

    assert_response :success
    assert_equal 1, process_count
    receipt = BillingWebhookEvent.find_by!(provider: "stripe", external_event_id: "evt_race_failed")
    assert_equal "ignored", receipt.status
    assert receipt.processed_at.present?
    assert_nil receipt.failed_at
    assert_nil receipt.error_code
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

  def stripe_event_payload(event_id:, event_type: "customer.subscription.updated", livemode: false, api_version: "2026-07-01", data_object: nil)
    JSON.generate(
      id: event_id,
      object: "event",
      type: event_type,
      livemode: livemode,
      api_version: api_version,
      data: {
        object: data_object || {
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

  def capture_rails_logs
    previous_logger = Rails.logger
    output = StringIO.new
    Rails.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(output))

    yield

    output.string
  ensure
    Rails.logger = previous_logger
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

  def with_processor_failure_count(initial_count)
    count = initial_count
    original_method = Billing::StripeWebhookProcessor.instance_method(:process_event!)
    Billing::StripeWebhookProcessor.define_method(:process_event!) do |_billing_webhook_event|
      count += 1
      raise "synthetic failure"
    end
    Billing::StripeWebhookProcessor.send(:private, :process_event!)

    yield -> { count }
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

  def with_receipt_create_race
    original_find_by = BillingWebhookEvent.method(:find_by)
    original_create = BillingWebhookEvent.method(:create!)
    find_by_calls = 0
    create_calls = 0

    BillingWebhookEvent.define_singleton_method(:find_by) do |*args, **kwargs|
      find_by_calls += 1
      next nil if find_by_calls == 1

      original_find_by.call(*args, **kwargs)
    end
    BillingWebhookEvent.define_singleton_method(:create!) do |*args, **kwargs|
      create_calls += 1
      raise ActiveRecord::RecordNotUnique if create_calls == 1

      original_create.call(*args, **kwargs)
    end

    yield
  ensure
    BillingWebhookEvent.define_singleton_method(:find_by, original_find_by)
    BillingWebhookEvent.define_singleton_method(:create!, original_create)
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
