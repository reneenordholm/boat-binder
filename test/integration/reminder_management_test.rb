require "test_helper"

class ReminderManagementTest < ActionDispatch::IntegrationTest
  test "captain creates completes reopens and edits a reminder" do
    sign_in_as
    vessel = create_vessel

    assert_difference -> { Reminder.count }, 1 do
      post reminders_path, params: {
        reminder: {
          asset_id: vessel.id,
          title: "Replace zincs",
          due_date: Date.tomorrow,
          reminder_type: "maintenance"
        }
      }
    end

    reminder = Reminder.find_by!(title: "Replace zincs")
    assert_redirected_to reminders_path

    patch reminder_path(reminder, status_action: "complete")
    assert_equal "completed", reminder.reload.status
    assert_not_nil reminder.completed_at

    patch reminder_path(reminder, status_action: "reopen")
    assert_equal "pending", reminder.reload.status
    assert_nil reminder.completed_at

    patch reminder_path(reminder), params: {
      reminder: {
        asset_id: vessel.id,
        title: "Replace shaft zincs",
        due_date: Date.current + 3.days,
        reminder_type: "maintenance",
        status: "pending"
      }
    }
    assert_equal "Replace shaft zincs", reminder.reload.title
  end
end
