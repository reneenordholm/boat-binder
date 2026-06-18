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

  test "asset must belong to selected account" do
    account = create_account(name: "Elliott Family")
    other_account = create_account(name: "Harbor North")
    vessel = create_vessel(account: other_account)

    document = Document.new(account: account, asset: vessel, title: "Insurance", document_type: "insurance")

    assert_not document.valid?
    assert_includes document.errors[:asset], "must belong to the selected owner"
  end
end
