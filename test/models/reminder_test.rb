require "test_helper"

class ReminderTest < ActiveSupport::TestCase
  test "can be completed" do
    reminder = Reminder.create!(asset: create_vessel, title: "Replace zincs", due_date: Date.current, reminder_type: "maintenance")

    reminder.complete!

    assert_equal "completed", reminder.reload.status
    assert_not_nil reminder.completed_at
  end

  test "can be reopened" do
    reminder = Reminder.create!(asset: create_vessel, title: "Replace zincs", due_date: Date.current, reminder_type: "maintenance")
    reminder.complete!

    reminder.reopen!

    assert_equal "pending", reminder.reload.status
    assert_nil reminder.completed_at
  end
end
