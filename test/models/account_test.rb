require "test_helper"

class AccountTest < ActiveSupport::TestCase
  include AccountTimeZoneContext

  test "requires a valid account type" do
    account = Account.new(name: "Hayes", account_type: "vendor")

    assert_not account.valid?
    assert_includes account.errors[:account_type], "is not included in the list"
  end

  test "defaults to Pacific time" do
    account = Account.new(name: "Hayes", account_type: "client")

    assert account.valid?
    assert_equal "America/Los_Angeles", account.time_zone
  end

  test "requires a supported time zone" do
    account = Account.new(name: "Hayes", account_type: "client", time_zone: "Mars/Base")

    assert_not account.valid?
    assert_includes account.errors[:time_zone], "is not included in the list"
  end

  test "database default is Pacific time for existing-account backfills" do
    default = Account.columns_hash.fetch("time_zone").default

    assert_equal "America/Los_Angeles", default
  end

  test "account time zone uses daylight saving offsets" do
    account = create_account(time_zone: "America/Los_Angeles")

    winter_time = account_local_time(Time.utc(2026, 1, 15, 20, 0), account)
    summer_time = account_local_time(Time.utc(2026, 7, 15, 20, 0), account)

    assert_equal "-08:00", winter_time.formatted_offset
    assert_equal "-07:00", summer_time.formatted_offset
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
