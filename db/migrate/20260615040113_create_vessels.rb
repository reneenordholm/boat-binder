class CreateVessels < ActiveRecord::Migration[8.1]
  def change
    create_table :vessels do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :make
      t.string :model
      t.integer :year
      t.decimal :length, precision: 6, scale: 2
      t.string :registration_number
      t.string :marina
      t.string :slip
      t.text :notes

      t.timestamps
    end

    add_index :vessels, :name
  end
end
