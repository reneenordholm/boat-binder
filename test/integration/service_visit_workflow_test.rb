require "test_helper"

class ServiceVisitWorkflowTest < ActionDispatch::IntegrationTest
  test "captain views all service visits from dashboard and navigation" do
    captain = create_user(email: "captain-visits@example.test")
    sign_in_as captain
    vessel = create_vessel(name: "Blue Meridian")
    other_vessel = create_vessel(account: create_account(name: "Harbor North"), name: "Tide Runner")
    vessel.service_visits.create!(performed_by_user: captain, visit_date: Date.current, summary: "Primary visit")
    other_vessel.service_visits.create!(performed_by_user: captain, visit_date: Date.yesterday, summary: "Second visit")

    get root_path

    assert_response :success
    assert_select "a[href='#{service_visits_path}']", text: "Service Visits"
    assert_select "a[href='#{service_visits_path}']", text: "View all"
    assert_select "nav.fixed a", text: "Vessels"
    assert_select "nav.fixed a", text: "Fleet", count: 0

    get service_visits_path

    assert_response :success
    assert_includes response.body, "Primary visit"
    assert_includes response.body, "Second visit"
    assert_includes response.body, "Blue Meridian"
    assert_includes response.body, "Tide Runner"
    assert_includes response.body, "A reverse-chronological service history"
    assert_operator response.body.index("Primary visit"), :<, response.body.index("Second visit")
  end

  test "service visits index renders empty state" do
    sign_in_as

    get service_visits_path

    assert_response :success
    assert_includes response.body, "No service visits recorded yet."
    assert_includes response.body, "owner-ready reports"
  end

  test "owner all service visits page is scoped to associated vessels" do
    owner_account = create_account(name: "Elliott Family")
    other_account = create_account(name: "Harbor North")
    owner_vessel = create_vessel(account: owner_account, name: "Blue Meridian")
    other_vessel = create_vessel(account: other_account, name: "Tide Runner")
    captain = create_user(email: "captain-scope@example.test")
    owner = create_user(email: "owner-visits@example.test", role: "owner")
    create_account_membership(user: owner, account: owner_account)
    owner_vessel.service_visits.create!(performed_by_user: captain, visit_date: Date.current, summary: "Owner visible visit")
    other_vessel.service_visits.create!(performed_by_user: captain, visit_date: Date.current, summary: "Restricted visit")
    sign_in_as owner

    get service_visits_path

    assert_response :success
    assert_includes response.body, "Owner visible visit"
    assert_includes response.body, "Blue Meridian"
    assert_not_includes response.body, "Restricted visit"
    assert_not_includes response.body, "Tide Runner"
  end

  test "owner cannot access out of scope service visit report" do
    owner_account = create_account(name: "Elliott Family")
    other_account = create_account(name: "Harbor North")
    create_vessel(account: owner_account, name: "Blue Meridian")
    other_vessel = create_vessel(account: other_account, name: "Tide Runner")
    captain = create_user(email: "captain-report-scope@example.test")
    owner = create_user(email: "owner-report-scope@example.test", role: "owner")
    create_account_membership(user: owner, account: owner_account)
    restricted_visit = other_vessel.service_visits.create!(
      performed_by_user: captain,
      visit_date: Date.current,
      summary: "Restricted visit report"
    )
    sign_in_as owner

    get vessel_service_visit_path(other_vessel, restricted_visit)

    assert_response :not_found
  end

  test "captain starts a visit with default engines checklist and battery checks" do
    sign_in_as
    vessel = create_vessel
    create_battery(asset: vessel, name: "House Battery 1")

    get new_vessel_service_visit_path(vessel)

    assert_response :success
    assert_includes response.body, "Port Engine Hours"
    assert_includes response.body, "Starboard Engine Hours"
    assert_includes response.body, "Bilge"
    assert_includes response.body, "Shore power"
    assert_includes response.body, "House Battery 1"
  end

  test "captain saves structured service visit data and report renders it" do
    sign_in_as
    vessel = create_vessel
    battery = create_battery(asset: vessel, name: "Port Start Battery")
    vessel.ensure_default_engines!
    port_engine = vessel.asset_engines.find_by!(name: "Port")
    starboard_engine = vessel.asset_engines.find_by!(name: "Starboard")

    assert_difference -> { ServiceVisit.count }, 1 do
      post vessel_service_visits_path(vessel), params: {
        service_visit: {
          visit_date: Date.current,
          location: "Bainbridge Marina, Slip C-18",
          summary: "Vessel checked and ready for weekend use.",
          condition_notes: "Decks clean and bilge dry.",
          follow_up_needed: "1",
          follow_up_notes: "Replace chafed spring line.",
          engine_readings: {
            port_engine.id.to_s => { hours: "124.5" },
            starboard_engine.id.to_s => { hours: "125.0" }
          },
          inspection_checks: {
            "0" => { checked: "1", notes: "Hull clean." },
            "1" => { checked: "1", notes: "Bilge dry." },
            "2" => { checked: "0", notes: "Cord strain relief should be watched." }
          },
          battery_checks: {
            battery.id.to_s => { checked: "1", voltage: "12.72", notes: "Charging normally." }
          }
        }
      }
    end

    visit = ServiceVisit.find_by!(summary: "Vessel checked and ready for weekend use.")
    assert_redirected_to vessel_service_visit_path(vessel, visit)
    assert_equal 2, visit.service_visit_engine_readings.count
    assert_equal 9, visit.service_visit_inspection_checks.count
    assert_equal 1, visit.service_visit_battery_checks.count
    assert_equal "Hull clean.", visit.service_visit_inspection_checks.find_by!(label: "Hull").notes
    assert_equal 12.72.to_d, visit.service_visit_battery_checks.first.voltage

    get vessel_service_visit_path(vessel, visit)
    assert_response :success
    assert_includes response.body, "Client-ready service report"
    assert_includes response.body, "Back to service visits"
    assert_includes response.body, "Port Engine"
    assert_includes response.body, "124.5"
    assert_includes response.body, "Inspection checklist"
    assert_includes response.body, "Hull clean."
    assert_includes response.body, "Port Start Battery"
    assert_includes response.body, "12.72 V"
    assert_includes response.body, "Replace chafed spring line."
    assert_includes response.body, "Follow-up items"
  end

  test "vessel page shows service history timeline" do
    captain = create_user(email: "captain-history@example.test")
    sign_in_as captain
    vessel = create_vessel(name: "Blue Meridian")
    vessel.service_visits.create!(
      performed_by_user: captain,
      visit_date: Date.current,
      summary: "Quarterly systems check",
      follow_up_needed: true,
      follow_up_notes: "Order spare impeller."
    )

    get vessel_path(vessel)

    assert_response :success
    assert_includes response.body, "Vessel history"
    assert_includes response.body, "Quarterly systems check"
    assert_includes response.body, "View all service visits"
    assert_includes response.body, "View visit details"
    assert_includes response.body, "Follow-up"
  end

  test "older service visit report without structured records renders" do
    sign_in_as
    vessel = create_vessel
    visit = vessel.service_visits.create!(
      performed_by_user: create_user(email: "legacy@example.test"),
      visit_date: Date.current,
      engine_hours: 88.4,
      summary: "Legacy report",
      condition_notes: "Legacy condition notes."
    )

    get vessel_service_visit_path(vessel, visit)

    assert_response :success
    assert_includes response.body, "88.4"
    assert_includes response.body, "Legacy condition notes."
    assert_includes response.body, "No battery checks were recorded"
  end

  test "captain creates and edits vessel batteries" do
    sign_in_as
    vessel = create_vessel

    assert_difference -> { AssetBattery.count }, 1 do
      post vessel_batteries_path(vessel), params: {
        asset_battery: {
          name: "House Battery 1",
          location: "Engine room",
          battery_type: "AGM",
          notes: "Installed spring 2025",
          active: "1"
        }
      }
    end

    battery = AssetBattery.find_by!(name: "House Battery 1")
    assert_redirected_to vessel_path(vessel, anchor: "batteries")

    patch vessel_battery_path(vessel, battery), params: {
      asset_battery: {
        name: "House Battery Bank",
        location: "Aft lazarette",
        battery_type: "Lithium",
        notes: "Monitor charging profile.",
        active: "0"
      }
    }

    assert_redirected_to vessel_path(vessel, anchor: "batteries")
    battery.reload
    assert_equal "House Battery Bank", battery.name
    assert_equal "Aft lazarette", battery.location
    assert_not battery.active?
  end
end
