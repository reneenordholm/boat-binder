class AddUserAccessFoundations < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string
    add_column :users, :active, :boolean, default: true, null: false
    add_index :users, :active

    create_table :account_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :access_level, default: "read_only", null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :account_memberships, [ :user_id, :account_id ], unique: true
    add_index :account_memberships, :active
    add_check_constraint :account_memberships, "access_level IN ('read_only', 'editor')", name: "chk_account_memberships_access_level"
  end
end
