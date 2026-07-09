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

  test "internal users upload valid vessel primary photos" do
    %w[captain admin].each do |role|
      sign_in_as create_user(email: "#{role}-photo@example.test", role: role)
      vessel = create_vessel(name: "Photo #{role.titleize}")

      patch vessel_path(vessel), params: {
        asset: {
          primary_photo: fixture_file_upload("sample.jpg", "image/jpeg")
        }
      }

      assert_redirected_to vessel_path(vessel)
      vessel.reload
      assert vessel.primary_photo.attached?
      assert_equal "image/jpeg", vessel.primary_photo.blob.content_type
    end
  end

  test "vessel edit form exposes image primary photo upload" do
    sign_in_as
    vessel = create_vessel

    get edit_vessel_path(vessel)

    assert_response :success
    assert_select "input[type=file][name=?][accept=?]", "asset[primary_photo]", Asset::PRIMARY_PHOTO_CONTENT_TYPES.join(",")
    assert_includes response.body, "Upload a JPEG, PNG, or WEBP image up to 10 MB."
  end

  test "invalid vessel primary photo file type is rejected" do
    sign_in_as
    vessel = create_vessel

    assert_no_difference -> { ActiveStorage::Blob.count } do
      assert_no_difference -> { ActiveStorage::Attachment.count } do
        patch vessel_path(vessel), params: {
          asset: {
            primary_photo: fixture_file_upload("sample.pdf", "application/pdf")
          }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_not vessel.reload.primary_photo.attached?
    assert_includes response.body, "Primary photo must be a JPEG, PNG, or WEBP image"
  end

  test "oversized vessel primary photo is rejected" do
    sign_in_as
    vessel = create_vessel
    oversized_file = Tempfile.new([ "oversized-primary-photo", ".jpg" ])

    begin
      oversized_file.binmode
      oversized_file.truncate(Asset::PRIMARY_PHOTO_MAX_SIZE + 1)
      oversized_file.rewind

      assert_no_difference -> { ActiveStorage::Blob.count } do
        assert_no_difference -> { ActiveStorage::Attachment.count } do
          patch vessel_path(vessel), params: {
            asset: {
              primary_photo: Rack::Test::UploadedFile.new(oversized_file.path, "image/jpeg", true)
            }
          }
        end
      end
    ensure
      oversized_file.close!
    end

    assert_response :unprocessable_entity
    assert_not vessel.reload.primary_photo.attached?
    assert_includes response.body, "Primary photo must be 10 MB or smaller"
  end

  test "vessel show displays primary photo when attached" do
    sign_in_as
    vessel = create_vessel
    vessel.primary_photo.attach(fixture_file_upload("sample.jpg", "image/jpeg"))

    get vessel_path(vessel)

    assert_response :success
    assert_select "img[alt=?]", "#{vessel.name} primary photo"

    get root_path

    assert_response :success
    assert_select "img[alt=?]", "#{vessel.name} primary photo"
  end

  test "vessel show and index display primary photo fallback" do
    sign_in_as
    vessel = create_vessel

    get vessel_path(vessel)

    assert_response :success
    assert_select "[aria-label=?]", "Primary photo placeholder for #{vessel.name}"

    get root_path

    assert_response :success
    assert_select "[aria-label=?]", "Primary photo placeholder for #{vessel.name}"

    get vessels_path

    assert_response :success
    assert_select "[aria-label=?]", "Primary photo placeholder for #{vessel.name}"
  end

  test "owner vessel list remains scoped when primary photos exist" do
    owner_account = create_account(name: "Elliott Family")
    other_account = create_account(name: "Harbor North")
    owner_vessel = create_vessel(account: owner_account, name: "Owner Vessel")
    other_vessel = create_vessel(account: other_account, name: "Restricted Vessel")
    owner_vessel.primary_photo.attach(fixture_file_upload("sample.jpg", "image/jpeg"))
    other_vessel.primary_photo.attach(fixture_file_upload("sample.png", "image/png"))
    owner = create_user(email: "owner-photo-scope@example.test", role: "owner")
    create_account_membership(user: owner, account: owner_account)
    sign_in_as owner

    get vessels_path

    assert_response :success
    assert_includes response.body, "Owner Vessel"
    assert_select "img[alt=?]", "Owner Vessel primary photo"
    assert_not_includes response.body, "Restricted Vessel"
    assert_select "img[alt=?]", "Restricted Vessel primary photo", count: 0
  end

  test "owner cannot update another account vessel primary photo" do
    owner_account = create_account(name: "Elliott Family")
    other_account = create_account(name: "Harbor North")
    other_vessel = create_vessel(account: other_account, name: "Restricted Vessel")
    owner = create_user(email: "owner-photo-update@example.test", role: "owner")
    create_account_membership(user: owner, account: owner_account)
    sign_in_as owner

    patch vessel_path(other_vessel), params: {
      asset: {
        primary_photo: fixture_file_upload("sample.jpg", "image/jpeg")
      }
    }

    assert_redirected_to root_path
    assert_not other_vessel.reload.primary_photo.attached?
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
