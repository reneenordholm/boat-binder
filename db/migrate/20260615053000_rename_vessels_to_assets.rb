class RenameVesselsToAssets < ActiveRecord::Migration[8.1]
  def up
    rename_table :vessels, :assets
    rename_index_if_exists :assets, "index_vessels_on_account_id", "index_assets_on_account_id"
    rename_index_if_exists :assets, "index_vessels_on_name", "index_assets_on_name"

    add_column :assets, :asset_type, :string, null: false, default: "vessel"
    add_index :assets, :asset_type
    add_index :assets, [ :account_id, :asset_type, :name ], unique: true
    add_index :assets, [ :account_id, :registration_number ], unique: true, where: "registration_number IS NOT NULL"

    rename_reference :service_visits, :vessel, :asset
    rename_reference :reminders, :vessel, :asset
    rename_reference :documents, :vessel, :asset
    rename_reference :binder_notes, :vessel, :asset

    add_check_constraint :assets, "asset_type IN ('vessel', 'home', 'pet', 'audit', 'other')", name: "chk_assets_asset_type"
    add_check_constraint :assets, "length IS NULL OR length > 0", name: "chk_assets_length_positive"
    add_check_constraint :assets, "year IS NULL OR (year > 1900 AND year <= 2100)", name: "chk_assets_year_reasonable"
    add_check_constraint :service_visits, "engine_hours IS NULL OR engine_hours >= 0", name: "chk_service_visits_engine_hours_non_negative"
    add_check_constraint :reminders, "status IN ('pending', 'completed')", name: "chk_reminders_status"
  end

  def down
    remove_check_constraint :reminders, name: "chk_reminders_status"
    remove_check_constraint :service_visits, name: "chk_service_visits_engine_hours_non_negative"
    remove_check_constraint :assets, name: "chk_assets_year_reasonable"
    remove_check_constraint :assets, name: "chk_assets_length_positive"
    remove_check_constraint :assets, name: "chk_assets_asset_type"

    rename_reference :binder_notes, :asset, :vessel
    rename_reference :documents, :asset, :vessel
    rename_reference :reminders, :asset, :vessel
    rename_reference :service_visits, :asset, :vessel

    remove_index :assets, column: [ :account_id, :registration_number ]
    remove_index :assets, column: [ :account_id, :asset_type, :name ]
    remove_index :assets, column: :asset_type
    remove_column :assets, :asset_type

    rename_index_if_exists :assets, "index_assets_on_name", "index_vessels_on_name"
    rename_index_if_exists :assets, "index_assets_on_account_id", "index_vessels_on_account_id"
    rename_table :assets, :vessels
  end

  private

  def rename_reference(table, old_name, new_name)
    rename_column table, "#{old_name}_id", "#{new_name}_id"
    rename_index_if_exists table, "index_#{table}_on_#{old_name}_id", "index_#{table}_on_#{new_name}_id"
  end

  def rename_index_if_exists(table, old_name, new_name)
    rename_index table, old_name, new_name if index_name_exists?(table, old_name)
  end
end
