class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :account, null: false, foreign_key: true
      t.references :vessel, null: true, foreign_key: true
      t.string :title, null: false
      t.string :document_type, null: false, default: "other"
      t.text :notes

      t.timestamps
    end

    add_index :documents, :document_type
  end
end
