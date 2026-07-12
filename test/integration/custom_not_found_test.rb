require "test_helper"

class CustomNotFoundTest < ActionDispatch::IntegrationTest
  setup do
    @show_exceptions = Rails.application.env_config["action_dispatch.show_exceptions"]
    @show_detailed_exceptions = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    Rails.application.env_config["action_dispatch.show_exceptions"] = :all
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
  end

  teardown do
    Rails.application.env_config["action_dispatch.show_exceptions"] = @show_exceptions
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = @show_detailed_exceptions
  end

  test "unknown route returns branded custom 404 for unauthenticated users" do
    get "/missing-channel-marker"

    assert_response :not_found
    assert_includes response.body, "Boat Binder"
    assert_includes response.body, "404"
    assert_includes response.body, "Return to sign in"
    assert_select "a[href='#{new_session_path}']", text: "Return to sign in"
    assert_approved_not_found_message
    assert_not_default_rails_error_page
  end

  test "post to unknown route returns custom 404 without secondary routing or csrf failure" do
    post "/missing-channel-marker", params: { discarded: "value" }

    assert_response :not_found
    assert_includes response.body, "Boat Binder"
    assert_includes response.body, "404"
    assert_includes response.body, "Return to sign in"
    assert_approved_not_found_message
    assert_not_includes response.body, "InvalidAuthenticityToken"
    assert_not_includes response.body, "No route matches"
  end

  test "patch to unknown route returns custom 404" do
    patch "/missing-channel-marker", params: { discarded: "value" }

    assert_response :not_found
    assert_includes response.body, "Boat Binder"
    assert_approved_not_found_message
    assert_not_default_rails_error_page
  end

  test "unknown route returns dashboard action for authenticated users" do
    sign_in_as create_user(email: "admin-not-found@example.test", role: "admin")

    get "/off-the-chart"

    assert_response :not_found
    assert_includes response.body, "Return to dashboard"
    assert_select "a[href='#{root_path}']", text: "Return to dashboard"
    assert_not_includes response.body, "Return to sign in"
    assert_approved_not_found_message
  end

  test "missing record returns custom 404 without exception details" do
    sign_in_as create_user(email: "captain-missing-record@example.test")

    get vessel_path("missing-vessel")

    assert_response :not_found
    assert_includes response.body, "Boat Binder"
    assert_approved_not_found_message
    assert_not_includes response.body, "ActiveRecord::RecordNotFound"
    assert_not_includes response.body, "missing-vessel"
    assert_not_default_rails_error_page
  end

  test "cross account record access returns custom 404 without revealing protected data" do
    owner_account = create_account(name: "Elliott Family")
    other_account = create_account(name: "Harbor North")
    restricted_vessel = create_vessel(account: other_account, name: "Restricted Tide")
    owner = create_user(email: "owner-cross-account-404@example.test", role: "owner")
    create_account_membership(user: owner, account: owner_account)
    sign_in_as owner

    get vessel_path(restricted_vessel)

    assert_response :not_found
    assert_includes response.body, "Boat Binder"
    assert_approved_not_found_message
    assert_not_includes response.body, "Restricted Tide"
    assert_not_includes response.body, "Harbor North"
    assert_not_includes response.body, restricted_vessel.slug
  end

  test "not found page renders mobile friendly structure without authenticated data" do
    get "/coordinates-not-found"

    assert_response :not_found
    assert_select "meta[name='viewport']"
    assert_select "section"
    assert_select "article"
    assert_not_includes response.body, "Sign out"
    assert_not_includes response.body, "Dashboard</span>"
  end

  test "application exceptions normalizes non get redispatches to their intended statuses" do
    unprocessable_env = Rack::MockRequest.env_for("/422", method: "PATCH")
    server_error_env = Rack::MockRequest.env_for("/500", method: "DELETE")

    unprocessable_status, _headers, unprocessable_body = ApplicationExceptions.call(unprocessable_env)
    unprocessable_body.close if unprocessable_body.respond_to?(:close)

    assert_equal 422, unprocessable_status
    assert_equal "PATCH", unprocessable_env["REQUEST_METHOD"]

    status, _headers, body = ApplicationExceptions.call(server_error_env)
    body.close if body.respond_to?(:close)

    assert_equal 500, status
    assert_equal "DELETE", server_error_env["REQUEST_METHOD"]
  end

  test "not found message fallback returns the default message for nil or empty collections" do
    assert_equal NotFoundMessage.default, NotFoundMessage.pick(seed: "anything", messages: nil)
    assert_equal NotFoundMessage.default, NotFoundMessage.pick(seed: "anything", messages: [])
  end

  test "not found message selection is deterministic for a valid collection" do
    messages = [ "Harbor not found.", "Chart not found." ]
    first_pick = NotFoundMessage.pick(seed: "stable-request-id", messages: messages)

    assert_equal first_pick, NotFoundMessage.pick(seed: "stable-request-id", messages: messages)
    assert_includes messages, first_pick
  end

  test "not found message invalid inputs are not silently swallowed" do
    assert_raises(NoMethodError) do
      NotFoundMessage.pick(seed: "invalid", messages: Object.new)
    end
  end

  test "errors controller keeps authenticity token verification enabled" do
    before_filters = ErrorsController._process_action_callbacks.select { |callback| callback.kind == :before }.map(&:filter)

    assert_includes before_filters, :verify_authenticity_token
  end

  private

  def assert_approved_not_found_message
    assert NotFoundMessage::MESSAGES.any? { |message| response.body.include?(ERB::Util.html_escape(message)) },
      "Expected one approved 404 message in response"
  end

  def assert_not_default_rails_error_page
    assert_not_includes response.body, "The page you were looking for doesn't exist"
    assert_not_includes response.body, "Routing Error"
    assert_not_includes response.body, "Rails.root"
  end
end
