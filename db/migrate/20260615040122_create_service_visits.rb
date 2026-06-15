class CreateServiceVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :service_visits do |t|
      t.references :vessel, null: false, foreign_key: true
      t.references :performed_by_user, null: false, foreign_key: { to_table: :users }
      t.date :visit_date, null: false
      t.decimal :engine_hours, precision: 8, scale: 1
      t.string :location
      t.text :summary
      t.text :condition_notes
      t.boolean :follow_up_needed, null: false, default: false
      t.text :follow_up_notes

      t.timestamps
    end

    add_index :service_visits, :visit_date
  end
end
