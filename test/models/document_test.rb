require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  test "asset is optional for binder-wide documents" do
    document = Document.new(account: create_account, title: "Insurance", document_type: "insurance")

    assert document.valid?
  end

  test "requires known document type" do
    document = Document.new(account: create_account, title: "Mystery", document_type: "unknown")

    assert_not document.valid?
    assert_includes document.errors[:document_type], "is not included in the list"
  end
end
