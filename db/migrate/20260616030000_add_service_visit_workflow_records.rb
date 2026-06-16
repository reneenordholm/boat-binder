class AddServiceVisitWorkflowRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :asset_engines do |t|
      t.references :asset, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, default: 0, null: false
      t.boolean :active, default: true, null: false
      t.text :notes

      t.timestamps
    end

    add_index :asset_engines, [ :asset_id, :position ]
    add_index :asset_engines, :active

    create_table :asset_batteries do |t|
      t.references :asset, null: false, foreign_key: true
      t.string :name, null: false
      t.string :location
      t.string :battery_type
      t.boolean :active, default: true, null: false
      t.text :notes

      t.timestamps
    end

    add_index :asset_batteries, [ :asset_id, :active ]
    add_index :asset_batteries, :name

    create_table :service_visit_engine_readings do |t|
      t.references :service_visit, null: false, foreign_key: true
      t.references :asset_engine, null: false, foreign_key: true
      t.decimal :hours, precision: 8, scale: 1

      t.timestamps
    end

    add_index :service_visit_engine_readings, [ :service_visit_id, :asset_engine_id ], unique: true, name: "idx_visit_engine_readings_unique_engine"
    add_check_constraint :service_visit_engine_readings, "hours IS NULL OR hours >= 0", name: "chk_service_visit_engine_readings_hours_non_negative"

    create_table :service_visit_inspection_checks do |t|
      t.references :service_visit, null: false, foreign_key: true
      t.string :label, null: false
      t.boolean :checked, default: false, null: false
      t.text :notes
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :service_visit_inspection_checks, [ :service_visit_id, :position ], name: "idx_visit_inspection_checks_position"

    create_table :service_visit_battery_checks do |t|
      t.references :service_visit, null: false, foreign_key: true
      t.references :asset_battery, null: false, foreign_key: true
      t.boolean :checked, default: false, null: false
      t.decimal :voltage, precision: 6, scale: 2
      t.text :notes

      t.timestamps
    end

    add_index :service_visit_battery_checks, [ :service_visit_id, :asset_battery_id ], unique: true, name: "idx_visit_battery_checks_unique_battery"
    add_check_constraint :service_visit_battery_checks, "voltage IS NULL OR voltage >= 0", name: "chk_service_visit_battery_checks_voltage_non_negative"
  end
end
