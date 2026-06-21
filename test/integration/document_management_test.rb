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
    assert_select "label[for='document_file']", "Capture image or upload file"
    assert_select "input[type='file'][name='document[file]'][accept=?][capture=?]", Document::ALLOWED_FILE_CONTENT_TYPES.join(","), "environment"
    assert_includes response.body, "On mobile: Capture a photo from your camera."
    assert_includes response.body, "On desktop: Upload a PDF or image."
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
