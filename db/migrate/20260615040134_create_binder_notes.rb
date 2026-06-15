class CreateBinderNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :binder_notes do |t|
      t.references :account, null: false, foreign_key: true
      t.references :vessel, null: true, foreign_key: true
      t.string :title, null: false
      t.text :body, null: false
      t.string :note_type, null: false, default: "general"

      t.timestamps
    end

    add_index :binder_notes, :note_type
  end
end
