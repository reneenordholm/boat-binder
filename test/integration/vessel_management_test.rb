require "test_helper"

class VesselManagementTest < ActionDispatch::IntegrationTest
  test "captain creates and searches for a vessel using slug URL" do
    sign_in_as
    account = create_account(name: "Elliott Family")

    assert_difference -> { Asset.vessels.count }, 1 do
      post vessels_path, params: {
        asset: {
          account_id: account.id,
          name: "North Star",
          make: "Ranger Tugs",
          model: "R-31",
          year: 2022,
          length: 31,
          registration_number: "NS-3100",
          marina: "Port Orchard Marina",
          slip: "B-12",
          notes: "Monitor battery voltage."
        }
      }
    end

    vessel = Asset.find_by!(name: "North Star")
    assert_redirected_to vessel_path(vessel)
    assert_equal "/vessels/north-star", vessel_path(vessel)

    get vessels_path(q: "Port Orchard")
    assert_response :success
    assert_includes response.body, "North Star"

    get vessels_path(q: "Orchard")
    assert_response :success
    assert_includes response.body, "North Star"
  end

  test "captain updates active status and deletes a vessel" do
    sign_in_as
    vessel = create_vessel

    patch vessel_path(vessel), params: { asset: { name: "Blue Meridian II", account_id: vessel.account_id, active: "0" } }
    assert_redirected_to vessel_path(vessel.reload)
    assert_equal "blue-meridian-ii", vessel.slug
    assert_not vessel.active?

    get vessels_path
    assert_response :success
    assert_not_includes response.body, "Blue Meridian II"

    get vessels_path(include_inactive: "1")
    assert_response :success
    assert_includes response.body, "Blue Meridian II"

    assert_difference -> { Asset.vessels.count }, -1 do
      delete vessel_path(vessel)
    end
    assert_redirected_to vessels_path
  end

  test "owner role cannot reassign a vessel account" do
    vessel = create_vessel
    other_account = create_account(name: "Other Owner")
    sign_in_as create_user(email: "owner@example.test", role: "owner")

    patch vessel_path(vessel), params: { asset: { name: vessel.name, account_id: other_account.id } }

    assert_redirected_to root_path
    follow_redirect!
    assert_includes response.body, Authorization::ACCESS_DENIED_MESSAGE
    assert_equal vessel.account, vessel.reload.account
  end

  test "captain deletes a due-dated note" do
    sign_in_as
    vessel = create_vessel
    note = vessel.binder_notes.create!(account: vessel.account, title: "Line chafe", body: "Replace spring line.", note_type: "issue", due_date: Date.tomorrow)

    assert_difference -> { BinderNote.count }, -1 do
      delete vessel_binder_note_path(vessel, note)
    end
    assert_redirected_to vessel_path(vessel, anchor: "notes")
  end

  test "captain edits a note" do
    sign_in_as
    vessel = create_vessel
    note = vessel.binder_notes.create!(account: vessel.account, title: "Line chafe", body: "Replace spring line.", note_type: "issue")

    patch vessel_binder_note_path(vessel, note), params: {
      binder_note: {
        title: "Replace spring line",
        body: "Line is chafed at the cleat.",
        note_type: "maintenance",
        due_date: Date.tomorrow
      }
    }

    assert_redirected_to vessel_path(vessel, anchor: "notes")
    note.reload
    assert_equal "Replace spring line", note.title
    assert_equal "maintenance", note.note_type
    assert_equal Date.tomorrow, note.due_date
  end
end
