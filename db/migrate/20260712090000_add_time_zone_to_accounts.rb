class AddTimeZoneToAccounts < ActiveRecord::Migration[8.1]
  DEFAULT_TIME_ZONE = "America/Los_Angeles"

  def up
    add_column :accounts, :time_zone, :string
    change_column_default :accounts, :time_zone, from: nil, to: DEFAULT_TIME_ZONE
    Account.reset_column_information
    Account.where(time_zone: [ nil, "" ]).update_all(time_zone: DEFAULT_TIME_ZONE)
    change_column_null :accounts, :time_zone, false
  end

  def down
    remove_column :accounts, :time_zone
  end
end
