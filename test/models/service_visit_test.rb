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
end
