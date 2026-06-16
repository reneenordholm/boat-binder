require "test_helper"

class ServiceVisitTest < ActiveSupport::TestCase
  test "belongs to an asset and captain" do
    asset = create_vessel
    user = create_user
    visit = ServiceVisit.create!(asset: asset, performed_by_user: user, visit_date: Date.current, engine_hours: 10.5)

    assert_equal asset, visit.asset
    assert_equal user, visit.performed_by_user
  end

  test "does not allow negative engine hours" do
    visit = ServiceVisit.new(asset: create_vessel, performed_by_user: create_user, visit_date: Date.current, engine_hours: -1)

    assert_not visit.valid?
    assert_includes visit.errors[:engine_hours], "must be greater than or equal to 0"
  end

  test "builds default inspection checks and engine readings" do
    vessel = create_vessel
    visit = ServiceVisit.new(asset: vessel, performed_by_user: create_user, visit_date: Date.current)

    visit.build_workflow_defaults

    assert_equal [ "Port Engine", "Starboard Engine" ], visit.ordered_engine_readings.map(&:display_name)
    assert_equal ServiceVisit::DEFAULT_INSPECTION_LABELS, visit.ordered_inspection_checks.map(&:label)
  end

  test "builds battery checks for active batteries only" do
    vessel = create_vessel
    active_battery = create_battery(asset: vessel, name: "House Battery 1")
    AssetBattery.create!(asset: vessel, name: "Old Battery", active: false)
    visit = ServiceVisit.new(asset: vessel, performed_by_user: create_user, visit_date: Date.current)

    visit.build_workflow_defaults

    assert_equal [ active_battery ], visit.service_visit_battery_checks.map(&:asset_battery)
  end
end
