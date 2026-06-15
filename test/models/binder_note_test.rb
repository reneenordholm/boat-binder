require "test_helper"

class BinderNoteTest < ActiveSupport::TestCase
  test "asset is optional for reusable binder notes" do
    note = BinderNote.new(account: create_account, title: "General SOP", body: "Use owner report template.", note_type: "general")

    assert note.valid?
  end
end
