require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "requires a valid account type" do
    account = Account.new(name: "Hayes", account_type: "vendor")

    assert_not account.valid?
    assert_includes account.errors[:account_type], "is not included in the list"
  end

  test "owns contacts and assets" do
    account = create_account
    contact = account.contacts.create!(name: "Avery Elliott", role: "Owner")
    asset = account.assets.create!(name: "Blue Meridian", asset_type: "vessel")

    assert_equal [ contact ], account.contacts.to_a
    assert_equal [ asset ], account.assets.to_a
    assert_equal [ asset ], account.vessel_assets.to_a
  end

  test "can be inactive without removing vessels" do
    account = create_account
    asset = account.assets.create!(name: "Blue Meridian", asset_type: "vessel")

    account.update!(active: false)

    assert_equal "Inactive", account.status_label
    assert_includes account.assets, asset
  end
end
