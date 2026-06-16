class AddActiveStatusToAccountsAndAssets < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :active, :boolean, null: false, default: true
    add_column :accounts, :notes, :text
    add_column :assets, :active, :boolean, null: false, default: true

    add_index :accounts, :active
    add_index :assets, :active
  end
end
