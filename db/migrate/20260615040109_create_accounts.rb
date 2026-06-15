class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :account_type, null: false, default: "client"

      t.timestamps
    end

    add_index :accounts, :account_type
  end
end
