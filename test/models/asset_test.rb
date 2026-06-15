require "test_helper"

class AssetTest < ActiveSupport::TestCase
  test "requires a name" do
    asset = Asset.new(account: create_account, asset_type: "vessel")

    assert_not asset.valid?
    assert_includes asset.errors[:name], "can't be blank"
  end

  test "requires a supported asset type" do
    asset = Asset.new(account: create_account, name: "Blue Meridian", asset_type: "vehicle")

    assert_not asset.valid?
    assert_includes asset.errors[:asset_type], "is not included in the list"
  end

  test "keeps vessel helpers for the captain workflow" do
    account = create_account(name: "Elliott Family")
    account.contacts.create!(name: "Avery Elliott", role: "Owner")
    asset = create_vessel(account: account)
    user = create_user
    older = asset.service_visits.create!(performed_by_user: user, visit_date: 2.days.ago.to_date)
    newer = asset.service_visits.create!(performed_by_user: user, visit_date: Date.current)

    assert_equal "Avery Elliott", asset.owner_name
    assert_equal newer, asset.last_visit
    assert_includes asset.service_visits, older
  end

  test "surfaces attention state from overdue reminders" do
    asset = create_vessel
    asset.reminders.create!(title: "Replace zincs", due_date: Date.yesterday, reminder_type: "maintenance")

    assert_equal "Needs attention", asset.status_label
    assert_equal :urgent, asset.status_tone
  end
end
