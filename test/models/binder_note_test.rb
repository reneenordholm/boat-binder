require "test_helper"

class BinderNoteTest < ActiveSupport::TestCase
  test "asset is optional for reusable binder notes" do
    note = BinderNote.new(account: create_account, title: "General SOP", body: "Use owner report template.", note_type: "general")

    assert note.valid?
  end

  test "due date marks a note for attention" do
    note = BinderNote.new(account: create_account, title: "Line chafe", body: "Replace spring line.", note_type: "issue", due_date: Date.tomorrow)

    assert note.attention_due?
  end
end
