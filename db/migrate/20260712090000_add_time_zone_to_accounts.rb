class AddTimeZoneToAccounts < ActiveRecord::Migration[8.1]
  DEFAULT_TIME_ZONE = "America/Los_Angeles"

  def up
    add_column :accounts, :time_zone, :string
    change_column_default :accounts, :time_zone, from: nil, to: DEFAULT_TIME_ZONE
    execute <<~SQL.squish
      UPDATE accounts
      SET time_zone = #{quote(DEFAULT_TIME_ZONE)}
      WHERE time_zone IS NULL OR time_zone = ''
    SQL
    change_column_null :accounts, :time_zone, false
  end

  def down
    remove_column :accounts, :time_zone
  end
end
