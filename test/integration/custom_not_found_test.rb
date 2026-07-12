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

  test "unexpected error route remains configured separately from not found" do
    assert_routing "/500", controller: "errors", action: "internal_server_error"
  end

  test "not found message fallback returns the default message" do
    assert_equal NotFoundMessage.default, NotFoundMessage.pick(seed: "anything", messages: [])
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
