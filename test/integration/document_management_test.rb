require "test_helper"

class DocumentManagementTest < ActionDispatch::IntegrationTest
  test "vessel page includes direct document link and document can be deleted" do
    sign_in_as
    vessel = create_vessel
    document = vessel.documents.create!(account: vessel.account, title: "Insurance", document_type: "insurance")
    document.file.attach(io: StringIO.new("policy"), filename: "policy.txt", content_type: "text/plain")

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
          file: fixture_file_upload("sample.txt", "text/plain")
        }
      }
    end

    document = Document.find_by!(title: "Updated insurance")
    assert_equal vessel, document.asset
    assert_equal vessel.account, document.account
    assert document.file.attached?
    assert_redirected_to vessel_path(vessel, anchor: "documents")
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

    assert_response :forbidden
  end
end
