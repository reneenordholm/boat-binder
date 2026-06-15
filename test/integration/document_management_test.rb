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
end
