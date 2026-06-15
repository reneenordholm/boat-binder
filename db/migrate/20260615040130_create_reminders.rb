class CreateReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :reminders do |t|
      t.references :vessel, null: false, foreign_key: true
      t.string :title, null: false
      t.date :due_date, null: false
      t.string :reminder_type, null: false, default: "other"
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :reminders, [ :status, :due_date ]
  end
end
