require "test_helper"
require "tempfile"

class DocumentManagementTest < ActionDispatch::IntegrationTest
  test "vessel page includes direct document link and document can be deleted" do
    sign_in_as
    vessel = create_vessel
    document = vessel.documents.create!(account: vessel.account, title: "Insurance", document_type: "insurance")
    document.file.attach(io: StringIO.new("policy"), filename: "policy.pdf", content_type: "application/pdf")

    get vessel_path(vessel)
    assert_response :success
    assert_includes response.body, "Open file"
    assert_includes response.body, "Download"

    assert_difference -> { Document.count }, -1 do
      delete vessel_document_path(vessel, document)
    end
    assert_redirected_to vessel_path(vessel, anchor: "documents")
    assert_not Document.exists?(document.id)
  end

  test "vessel page renders six recent documents with attached and missing file controls" do
    sign_in_as
    vessel = create_vessel
    older_document = vessel.documents.create!(account: vessel.account, title: "Older document", document_type: "other", created_at: 8.days.ago)

    6.times do |index|
      document = vessel.documents.create!(
        account: vessel.account,
        title: "Recent document #{index + 1}",
        document_type: "other",
        created_at: (index + 1).hours.ago
      )
      document.file.attach(fixture_file_upload("sample.pdf", "application/pdf")) if index.even?
    end

    get vessel_path(vessel)

    assert_response :success
    assert_not_includes response.body, older_document.title
    assert_select "#documents a", text: /Recent document/, count: 6
    assert_includes response.body, "No file attached"
    assert_includes response.body, "Open file"
    assert_includes response.body, "Download"
    assert_select "#documents a[href^='/rails/active_storage']", minimum: 1
  end

  test "document index shows view edit and metadata only status" do
    account = create_account(name: "Elliott Family")
    vessel = create_vessel(account: account)
    document = vessel.documents.create!(account: account, title: "Metadata only", document_type: "insurance")
    attached_document = vessel.documents.create!(account: account, title: "Attached file", document_type: "registration")
    attached_document.file.attach(fixture_file_upload("sample.pdf", "application/pdf"))
    editor_owner = create_user(email: "document-index-editor@example.test", role: "owner")
    create_account_membership(user: editor_owner, account: account, access_level: "editor")
    sign_in_as editor_owner

    get documents_path

    assert_response :success
    assert_select "a[href=?]", document_path(document), text: "Metadata only"
    assert_select "a[href=?]", document_path(document), text: "View"
    assert_select "a[href=?]", edit_document_path(document), text: "Edit / Add file"
    assert_includes response.body, "No file attached"
    assert_select "a[href=?]", document_path(attached_document), text: "Attached file"
    assert_includes response.body, "Open file"
    assert_includes response.body, "Download"
  end

  test "owner editor can view and edit document metadata" do
    account = create_account(name: "Elliott Family")
    vessel = create_vessel(account: account)
    document = vessel.documents.create!(
      account: account,
      title: "Insurance binder",
      document_type: "insurance",
      notes: "Original notes."
    )
    editor_owner = create_user(email: "document-editor@example.test", role: "owner")
    create_account_membership(user: editor_owner, account: account, access_level: "editor")
    sign_in_as editor_owner

    get document_path(document)
    assert_response :success
    assert_includes response.body, "No file is currently attached."
    assert_select "a[href=?]", edit_document_path(document), text: "Edit / Add file"

    patch document_path(document), params: {
      document: {
        account_id: account.id,
        asset_id: vessel.id,
        title: "Updated insurance",
        document_type: "registration",
        notes: "Updated by owner editor."
      }
    }

    assert_redirected_to vessel_path(vessel, anchor: "documents")
    document.reload
    assert_equal "Updated insurance", document.title
    assert_equal "registration", document.document_type
    assert_equal "Updated by owner editor.", document.notes
    assert_not document.file.attached?
  end

  test "owner editor can attach a file to a metadata only document" do
    account = create_account(name: "Elliott Family")
    document = Document.create!(account: account, title: "Registration", document_type: "registration")
    editor_owner = create_user(email: "document-attach-editor@example.test", role: "owner")
    create_account_membership(user: editor_owner, account: account, access_level: "editor")
    sign_in_as editor_owner

    patch document_path(document), params: {
      document: {
        account_id: account.id,
        title: document.title,
        document_type: document.document_type,
        file: fixture_file_upload("sample.pdf", "application/pdf")
      }
    }

    assert_redirected_to document_path(document)
    assert document.reload.file.attached?
    assert_equal "application/pdf", document.file.blob.content_type
  end

  test "owner editor can replace an existing file and metadata updates preserve attachment" do
    account = create_account(name: "Elliott Family")
    document = Document.create!(account: account, title: "Receipt", document_type: "receipt")
    document.file.attach(fixture_file_upload("sample.pdf", "application/pdf"))
    original_blob_id = document.file.blob.id
    editor_owner = create_user(email: "document-replace-editor@example.test", role: "owner")
    create_account_membership(user: editor_owner, account: account, access_level: "editor")
    sign_in_as editor_owner

    patch document_path(document), params: {
      document: {
        account_id: account.id,
        title: "Receipt renamed",
        document_type: document.document_type,
        notes: "No replacement file selected."
      }
    }

    assert_redirected_to document_path(document)
    document.reload
    assert_equal "Receipt renamed", document.title
    assert_equal original_blob_id, document.file.blob.id

    patch document_path(document), params: {
      document: {
        account_id: account.id,
        title: document.title,
        document_type: document.document_type,
        file: fixture_file_upload("sample.png", "image/png")
      }
    }

    assert_redirected_to document_path(document)
    document.reload
    assert document.file.attached?
    assert_not_equal original_blob_id, document.file.blob.id
    assert_equal "image/png", document.file.blob.content_type
  end

  test "read only owner can view but cannot edit replace or delete documents" do
    account = create_account(name: "Elliott Family")
    document = Document.create!(account: account, title: "Read only document", document_type: "other")
    read_only_owner = create_user(email: "document-readonly@example.test", role: "owner")
    create_account_membership(user: read_only_owner, account: account, access_level: "read_only")
    sign_in_as read_only_owner

    get document_path(document)
    assert_response :success
    assert_select "a[href=?]", edit_document_path(document), count: 0

    get edit_document_path(document)
    assert_access_denied_redirect

    patch document_path(document), params: {
      document: {
        account_id: account.id,
        title: "Blocked",
        document_type: "other",
        file: fixture_file_upload("sample.pdf", "application/pdf")
      }
    }
    assert_access_denied_redirect

    assert_no_difference -> { Document.count } do
      delete document_path(document)
    end
    assert_access_denied_redirect
    assert_equal "Read only document", document.reload.title
    assert_not document.file.attached?
  end

  test "owner editor cannot view or mutate documents in another account" do
    account = create_account(name: "Elliott Family")
    other_account = create_account(name: "Harbor North")
    document = Document.create!(account: other_account, title: "Private document", document_type: "other")
    editor_owner = create_user(email: "document-scope-editor@example.test", role: "owner")
    create_account_membership(user: editor_owner, account: account, access_level: "editor")
    sign_in_as editor_owner

    get document_path(document)
    assert_response :not_found

    get edit_document_path(document)
    assert_response :not_found

    patch document_path(document), params: {
      document: {
        account_id: other_account.id,
        title: "Blocked",
        document_type: "other"
      }
    }
    assert_response :not_found

    delete document_path(document)
    assert_response :not_found
    assert Document.exists?(document.id)
  end

  test "crafted owner editor relationship requests cannot escape manageable accounts" do
    account = create_account(name: "Elliott Family")
    other_account = create_account(name: "Harbor North")
    vessel = create_vessel(account: account)
    other_vessel = create_vessel(account: other_account, name: "Restricted Vessel")
    document = vessel.documents.create!(account: account, title: "Managed document", document_type: "other")
    editor_owner = create_user(email: "document-crafted-editor@example.test", role: "owner")
    create_account_membership(user: editor_owner, account: account, access_level: "editor")
    sign_in_as editor_owner

    patch document_path(document), params: {
      document: {
        account_id: other_account.id,
        asset_id: other_vessel.id,
        title: "Crafted update",
        document_type: "other"
      }
    }

    assert_response :not_found
    document.reload
    assert_equal account, document.account
    assert_equal vessel, document.asset
    assert_equal "Managed document", document.title
  end

  test "invalid edit upload rerenders without replacing existing attachment" do
    account = create_account(name: "Elliott Family")
    document = Document.create!(account: account, title: "Safe file", document_type: "other")
    document.file.attach(fixture_file_upload("sample.pdf", "application/pdf"))
    original_blob_id = document.file.blob.id
    editor_owner = create_user(email: "document-invalid-editor@example.test", role: "owner")
    create_account_membership(user: editor_owner, account: account, access_level: "editor")
    sign_in_as editor_owner

    patch document_path(document), params: {
      document: {
        account_id: account.id,
        title: "Attempted bad replacement",
        document_type: "other",
        file: fixture_file_upload("sample.exe", "application/x-msdownload")
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "File must be a PDF, JPEG, PNG, or WEBP file"
    document.reload
    assert_equal "Safe file", document.title
    assert_equal original_blob_id, document.file.blob.id
  end

  test "oversized edit upload rerenders without replacing existing attachment" do
    account = create_account(name: "Elliott Family")
    document = Document.create!(account: account, title: "Sized file", document_type: "other")
    document.file.attach(fixture_file_upload("sample.pdf", "application/pdf"))
    original_blob_id = document.file.blob.id
    editor_owner = create_user(email: "document-oversized-editor@example.test", role: "owner")
    create_account_membership(user: editor_owner, account: account, access_level: "editor")
    oversized_file = Tempfile.new([ "oversized-edit", ".pdf" ])
    sign_in_as editor_owner

    begin
      oversized_file.binmode
      oversized_file.truncate(Document::MAX_FILE_SIZE + 1)
      oversized_file.rewind

      patch document_path(document), params: {
        document: {
          account_id: account.id,
          title: "Attempted oversized replacement",
          document_type: "other",
          file: Rack::Test::UploadedFile.new(oversized_file.path, "application/pdf", true)
        }
      }
    ensure
      oversized_file.close!
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "File must be 25 MB or smaller"
    document.reload
    assert_equal "Sized file", document.title
    assert_equal original_blob_id, document.file.blob.id
  end

  test "captain creates a document from main documents page and associates it with a vessel" do
    sign_in_as
    vessel = create_vessel

    get new_document_path
    assert_response :success
    assert_select "label", "Owner"
    assert_select "label", "Vessel"

    assert_difference -> { Document.count }, 1 do
      post documents_path, params: {
        document: {
          account_id: vessel.account_id,
          asset_id: vessel.id,
          title: "Updated insurance",
          document_type: "insurance",
          notes: "Uploaded from library.",
          file: fixture_file_upload("sample.pdf", "application/pdf")
        }
      }
    end

    document = Document.find_by!(title: "Updated insurance")
    assert_equal vessel, document.asset
    assert_equal vessel.account, document.account
    assert document.file.attached?
    assert_redirected_to vessel_path(vessel, anchor: "documents")
  end

  test "captain cannot create a document with mismatched owner and vessel" do
    sign_in_as
    account = create_account(name: "Elliott Family")
    other_vessel = create_vessel(account: create_account(name: "Harbor North"))

    assert_no_difference -> { Document.count } do
      post documents_path, params: {
        document: {
          account_id: account.id,
          asset_id: other_vessel.id,
          title: "Mismatched insurance",
          document_type: "insurance",
          file: fixture_file_upload("sample.pdf", "application/pdf")
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "must belong to the selected owner"
  end

  test "new document form filters vessels and disables double submit" do
    sign_in_as
    vessel = create_vessel

    get new_document_path

    assert_response :success
    assert_select "select[data-dependent-vessels-target='asset'] option[data-account-id='#{vessel.account_id}'][value='#{vessel.id}']", vessel.name
    assert_select "label[for='document_file']", "Choose document or photo"
    assert_select "input[type='file'][name='document[file]'][accept=?]", Document::ALLOWED_FILE_CONTENT_TYPES.join(",")
    assert_select "input[type='file'][name='document[file]'][capture]", count: 0
    assert_includes response.body, "choose a file, select a photo, or take a new photo"
    assert_includes response.body, "upload a PDF or image"
    assert_select "input[type=submit][data-turbo-submits-with=?]", "Uploading..."
  end

  test "document uploads accept allowed PDF and image content types" do
    sign_in_as
    vessel = create_vessel
    allowed_uploads = {
      "sample.pdf" => "application/pdf",
      "sample.jpg" => "image/jpeg",
      "sample.png" => "image/png",
      "sample.webp" => "image/webp"
    }

    allowed_uploads.each do |filename, content_type|
      assert_difference -> { Document.count }, 1 do
        post documents_path, params: {
          document: {
            account_id: vessel.account_id,
            asset_id: vessel.id,
            title: "Allowed #{content_type}",
            document_type: "other",
            file: fixture_file_upload(filename, content_type)
          }
        }
      end

      document = Document.find_by!(title: "Allowed #{content_type}")
      assert_equal content_type, document.file.blob.content_type
      assert_redirected_to vessel_path(vessel, anchor: "documents")
    end
  end

  test "document upload MIME detection uses file contents and preserves upload IO" do
    sign_in_as
    vessel = create_vessel
    upload = fixture_file_upload("sample.png", "text/plain")
    upload.tempfile.rewind
    upload.tempfile.read(10)
    original_position = upload.tempfile.pos
    assert_operator original_position, :>, 0

    assert_nil Document.file_upload_error(upload)
    assert_equal original_position, upload.tempfile.pos

    upload.tempfile.rewind

    assert_difference -> { Document.count }, 1 do
      post documents_path, params: {
        document: {
          account_id: vessel.account_id,
          asset_id: vessel.id,
          title: "Detected image upload",
          document_type: "other",
          file: upload
        }
      }
    end

    document = Document.find_by!(title: "Detected image upload")
    assert_equal "image/png", document.file.blob.content_type
    assert_redirected_to vessel_path(vessel, anchor: "documents")
  end

  test "document uploads reject spoofed allowed content types" do
    sign_in_as
    vessel = create_vessel

    assert_no_difference -> { Document.count } do
      assert_no_difference -> { ActiveStorage::Blob.count } do
        assert_no_difference -> { ActiveStorage::Attachment.count } do
          post documents_path, params: {
            document: {
              account_id: vessel.account_id,
              asset_id: vessel.id,
              title: "Spoofed executable",
              document_type: "other",
              file: fixture_file_upload("sample.exe", "image/jpeg")
            }
          }
        end
      end
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "File must be a PDF, JPEG, PNG, or WEBP file"
  end

  test "document uploads reject executable and unknown content types" do
    sign_in_as
    vessel = create_vessel
    rejected_uploads = {
      "sample.exe" => "application/x-msdownload",
      "sample.bin" => "application/octet-stream"
    }

    rejected_uploads.each do |filename, content_type|
      assert_no_difference -> { Document.count } do
        assert_no_difference -> { ActiveStorage::Blob.count } do
          assert_no_difference -> { ActiveStorage::Attachment.count } do
            post documents_path, params: {
              document: {
                account_id: vessel.account_id,
                asset_id: vessel.id,
                title: "Rejected #{content_type}",
                document_type: "other",
                file: fixture_file_upload(filename, content_type)
              }
            }
          end
        end
      end

      assert_response :unprocessable_entity
      assert_includes response.body, "File must be a PDF, JPEG, PNG, or WEBP file"
    end
  end

  test "document uploads reject files over the size limit" do
    sign_in_as
    vessel = create_vessel
    oversized_file = Tempfile.new([ "oversized", ".pdf" ])

    begin
      oversized_file.binmode
      oversized_file.truncate(Document::MAX_FILE_SIZE + 1)
      oversized_file.rewind

      assert_no_difference -> { Document.count } do
        assert_no_difference -> { ActiveStorage::Blob.count } do
          assert_no_difference -> { ActiveStorage::Attachment.count } do
            post documents_path, params: {
              document: {
                account_id: vessel.account_id,
                asset_id: vessel.id,
                title: "Oversized upload",
                document_type: "other",
                file: Rack::Test::UploadedFile.new(oversized_file.path, "application/pdf", true)
              }
            }
          end
        end
      end
    ensure
      oversized_file.close!
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "File must be 25 MB or smaller"
  end

  test "owner role cannot assign a new document to a vessel" do
    vessel = create_vessel
    sign_in_as create_user(email: "owner@example.test", role: "owner")

    assert_no_difference -> { Document.count } do
      post documents_path, params: {
        document: {
          account_id: vessel.account_id,
          asset_id: vessel.id,
          title: "Private upload",
          document_type: "insurance"
        }
      }
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_includes response.body, Authorization::ACCESS_DENIED_MESSAGE
  end
end
