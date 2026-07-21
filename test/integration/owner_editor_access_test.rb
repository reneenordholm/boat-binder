require "test_helper"

class OwnerEditorAccessTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_account(name: "Elliott Family")
    @other_account = create_account(name: "Harbor North")
    @vessel = create_vessel(account: @account, name: "Blue Meridian")
    @other_vessel = create_vessel(account: @other_account, name: "Tide Runner")

    @editor_owner = create_user(email: "editor-owner@example.test", role: "owner", name: "Editor Owner")
    create_account_membership(user: @editor_owner, account: @account, access_level: "editor")

    @read_only_owner = create_user(email: "readonly-owner@example.test", role: "owner", name: "Read Only Owner")
    create_account_membership(user: @read_only_owner, account: @account, access_level: "read_only")
  end

  test "internal users retain write access" do
    captain = create_user(email: "captain-editor-access@example.test", role: "captain")
    sign_in_as captain

    patch vessel_path(@vessel), params: {
      asset: { name: "Blue Meridian II", account_id: @account.id }
    }

    assert_redirected_to vessel_path(@vessel.reload)
    assert_equal "Blue Meridian II", @vessel.name
  end

  test "editor owner can create and edit a note in their account" do
    sign_in_as @editor_owner

    assert_difference -> { @vessel.binder_notes.count }, 1 do
      post vessel_binder_notes_path(@vessel), params: {
        binder_note: {
          title: "Owner preference",
          body: "Use the north gate after hours.",
          note_type: "owner_preference",
          due_date: Date.tomorrow
        }
      }
    end

    note = @vessel.binder_notes.order(:created_at).last
    assert_redirected_to vessel_path(@vessel, anchor: "notes")

    patch vessel_binder_note_path(@vessel, note), params: {
      binder_note: {
        title: "Updated owner preference",
        body: note.body,
        note_type: note.note_type,
        due_date: note.due_date
      }
    }

    assert_redirected_to vessel_path(@vessel, anchor: "notes")
    assert_equal "Updated owner preference", note.reload.title

    assert_difference -> { @vessel.binder_notes.count }, -1 do
      delete vessel_binder_note_path(@vessel, note)
    end

    assert_redirected_to vessel_path(@vessel, anchor: "notes")
  end

  test "read only owner cannot create or edit a note" do
    note = @vessel.binder_notes.create!(
      account: @account,
      title: "Existing note",
      body: "Original body",
      note_type: "general"
    )
    sign_in_as @read_only_owner

    assert_no_difference -> { @vessel.binder_notes.count } do
      post vessel_binder_notes_path(@vessel), params: {
        binder_note: { title: "Blocked note", body: "Nope", note_type: "general" }
      }
    end
    assert_access_denied_redirect

    patch vessel_binder_note_path(@vessel, note), params: {
      binder_note: { title: "Blocked edit", body: note.body, note_type: note.note_type }
    }
    assert_access_denied_redirect
    assert_equal "Existing note", note.reload.title
  end

  test "editor owner can create and update a reminder in their account" do
    sign_in_as @editor_owner

    assert_difference -> { @vessel.reminders.count }, 1 do
      post reminders_path, params: {
        reminder: {
          asset_id: @vessel.id,
          title: "Renew registration",
          due_date: Date.tomorrow,
          reminder_type: "registration"
        }
      }
    end

    reminder = @vessel.reminders.order(:created_at).last
    assert_redirected_to reminders_path

    patch reminder_path(reminder), params: {
      reminder: {
        asset_id: @vessel.id,
        title: "Renew tabs",
        due_date: Date.tomorrow + 1.day,
        reminder_type: "registration",
        status: "pending"
      }
    }

    assert_redirected_to reminders_path
    assert_equal "Renew tabs", reminder.reload.title

    patch reminder_path(reminder, status_action: "complete"), params: {
      reminder: { asset_id: @vessel.id }
    }

    assert_redirected_to reminders_path
    assert_equal "completed", reminder.reload.status
  end

  test "editor owner can edit permitted vessel fields" do
    sign_in_as @editor_owner

    patch vessel_path(@vessel), params: {
      asset: {
        account_id: @account.id,
        name: "Blue Meridian Updated",
        marina: "Elliott Bay Marina",
        slip: "B-12"
      }
    }

    assert_redirected_to vessel_path(@vessel.reload)
    assert_equal "Blue Meridian Updated", @vessel.name
    assert_equal "Elliott Bay Marina", @vessel.marina
    assert_equal "B-12", @vessel.slip
  end

  test "editor owner can upload and replace a vessel primary photo" do
    sign_in_as @editor_owner

    patch vessel_path(@vessel), params: {
      asset: {
        account_id: @account.id,
        name: @vessel.name,
        primary_photo: fixture_file_upload("sample.jpg", "image/jpeg")
      }
    }

    assert_redirected_to vessel_path(@vessel.reload)
    assert @vessel.primary_photo.attached?
    first_blob_id = @vessel.primary_photo.blob.id

    patch vessel_path(@vessel), params: {
      asset: {
        account_id: @account.id,
        name: @vessel.name,
        primary_photo: fixture_file_upload("sample.png", "image/png")
      }
    }

    assert_redirected_to vessel_path(@vessel.reload)
    assert @vessel.primary_photo.attached?
    assert_not_equal first_blob_id, @vessel.primary_photo.blob.id
    assert_equal "image/png", @vessel.primary_photo.blob.content_type
  end

  test "editor owner can create a document with a supported file" do
    sign_in_as @editor_owner

    assert_difference -> { @vessel.documents.count }, 1 do
      post vessel_documents_path(@vessel), params: {
        document: {
          title: "Insurance binder",
          document_type: "insurance",
          notes: "Uploaded by owner.",
          file: fixture_file_upload("sample.pdf", "application/pdf")
        }
      }
    end

    document = @vessel.documents.order(:created_at).last
    assert_redirected_to vessel_path(@vessel, anchor: "documents")
    assert document.file.attached?
    assert_equal "application/pdf", document.file.blob.content_type

    assert_difference -> { @vessel.documents.count }, -1 do
      delete vessel_document_path(@vessel, document)
    end

    assert_redirected_to vessel_path(@vessel, anchor: "documents")
  end

  test "editor membership for one account does not allow modifying a read only account" do
    create_account_membership(user: @editor_owner, account: @other_account, access_level: "read_only")
    sign_in_as @editor_owner

    patch vessel_path(@other_vessel), params: {
      asset: {
        account_id: @other_account.id,
        name: "Unauthorized update"
      }
    }

    assert_access_denied_redirect
    assert_equal "Tide Runner", @other_vessel.reload.name
  end

  test "inactive editor membership does not grant write access" do
    inactive_owner = create_user(email: "inactive-editor-owner@example.test", role: "owner")
    create_account_membership(user: inactive_owner, account: @account, access_level: "editor", active: false)
    sign_in_as inactive_owner

    assert_no_difference -> { @vessel.binder_notes.count } do
      post vessel_binder_notes_path(@vessel), params: {
        binder_note: { title: "Inactive edit", body: "Blocked", note_type: "general" }
      }
    end

    assert_access_denied_redirect
  end

  test "editor owner sees account write controls while read only owner does not" do
    note = @vessel.binder_notes.create!(
      account: @account,
      title: "Visible note",
      body: "Original",
      note_type: "general"
    )

    sign_in_as @editor_owner
    get vessel_path(@vessel)

    assert_response :success
    assert_select "a[href=?]", edit_vessel_path(@vessel), text: "Edit"
    assert_select "a[href=?]", new_vessel_document_path(@vessel), text: "Upload"
    assert_select "form[action=?]", vessel_binder_notes_path(@vessel)
    assert_select "a[href=?]", edit_vessel_binder_note_path(@vessel, note), text: "Edit"
    assert_select "a[href=?]", new_vessel_service_visit_path(@vessel), count: 0

    sign_in_as @read_only_owner
    get vessel_path(@vessel)

    assert_response :success
    assert_select "a[href=?]", edit_vessel_path(@vessel), text: "Edit", count: 0
    assert_select "a[href=?]", new_vessel_document_path(@vessel), count: 0
    assert_select "form[action=?]", vessel_binder_notes_path(@vessel), count: 0
    assert_select "a[href=?]", edit_vessel_binder_note_path(@vessel, note), count: 0
  end

  private

  def assert_access_denied_redirect
    assert_redirected_to root_path
    follow_redirect!
    assert_includes response.body, Authorization::ACCESS_DENIED_MESSAGE
  end
end
