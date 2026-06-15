require "test_helper"

class ReminderTest < ActiveSupport::TestCase
  test "can be completed" do
    reminder = Reminder.create!(asset: create_vessel, title: "Replace zincs", due_date: Date.current, reminder_type: "maintenance")

    reminder.complete!

    assert_equal "completed", reminder.reload.status
  end
end
