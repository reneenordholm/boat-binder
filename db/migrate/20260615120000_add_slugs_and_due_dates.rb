class AddSlugsAndDueDates < ActiveRecord::Migration[8.1]
  require "set"

  class MigrationAsset < ActiveRecord::Base
    self.table_name = "assets"
  end

  def up
    add_column :assets, :slug, :string
    add_column :binder_notes, :due_date, :date
    add_column :reminders, :completed_at, :datetime

    MigrationAsset.reset_column_information
    used_slugs = Set.new

    MigrationAsset.order(:id).find_each do |asset|
      base_slug = asset.name.to_s.parameterize.presence || "vessel-#{asset.id}"
      slug = base_slug
      suffix = 2

      while used_slugs.include?(slug) || MigrationAsset.where(slug: slug).where.not(id: asset.id).exists?
        slug = "#{base_slug}-#{suffix}"
        suffix += 1
      end

      asset.update_columns(slug: slug)
      used_slugs.add(slug)
    end

    change_column_null :assets, :slug, false
    add_index :assets, :slug, unique: true
    add_index :binder_notes, :due_date
    add_index :reminders, :completed_at
  end

  def down
    remove_index :reminders, :completed_at
    remove_index :binder_notes, :due_date
    remove_index :assets, :slug
    remove_column :reminders, :completed_at
    remove_column :binder_notes, :due_date
    remove_column :assets, :slug
  end
end
