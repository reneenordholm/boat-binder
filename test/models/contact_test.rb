require "test_helper"

class ContactTest < ActiveSupport::TestCase
  test "validates email format when present" do
    contact = Contact.new(account: create_account, name: "Avery", email: "not-an-email")

    assert_not contact.valid?
    assert_includes contact.errors[:email], "is invalid"
  end
end
