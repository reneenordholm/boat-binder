# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_15_213000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "account_type", default: "client", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.index ["account_type"], name: "index_accounts_on_account_type"
    t.index ["active"], name: "index_accounts_on_active"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "assets", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "active", default: true, null: false
    t.string "asset_type", default: "vessel", null: false
    t.datetime "created_at", null: false
    t.decimal "length", precision: 6, scale: 2
    t.string "make"
    t.string "marina"
    t.string "model"
    t.string "name", null: false
    t.text "notes"
    t.string "registration_number"
    t.string "slip"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.integer "year"
    t.index ["account_id", "asset_type", "name"], name: "index_assets_on_account_id_and_asset_type_and_name", unique: true
    t.index ["account_id", "registration_number"], name: "index_assets_on_account_id_and_registration_number", unique: true, where: "(registration_number IS NOT NULL)"
    t.index ["account_id"], name: "index_assets_on_account_id"
    t.index ["active"], name: "index_assets_on_active"
    t.index ["asset_type"], name: "index_assets_on_asset_type"
    t.index ["name"], name: "index_assets_on_name"
    t.index ["slug"], name: "index_assets_on_slug", unique: true
    t.check_constraint "asset_type::text = ANY (ARRAY['vessel'::character varying, 'home'::character varying, 'pet'::character varying, 'audit'::character varying, 'other'::character varying]::text[])", name: "chk_assets_asset_type"
    t.check_constraint "length IS NULL OR length > 0::numeric", name: "chk_assets_length_positive"
    t.check_constraint "year IS NULL OR year > 1900 AND year <= 2100", name: "chk_assets_year_reasonable"
  end

  create_table "binder_notes", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "asset_id"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.date "due_date"
    t.string "note_type", default: "general", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_binder_notes_on_account_id"
    t.index ["asset_id"], name: "index_binder_notes_on_asset_id"
    t.index ["due_date"], name: "index_binder_notes_on_due_date"
    t.index ["note_type"], name: "index_binder_notes_on_note_type"
  end

  create_table "contacts", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.string "phone"
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_contacts_on_account_id"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "asset_id"
    t.datetime "created_at", null: false
    t.string "document_type", default: "other", null: false
    t.text "notes"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_documents_on_account_id"
    t.index ["asset_id"], name: "index_documents_on_asset_id"
    t.index ["document_type"], name: "index_documents_on_document_type"
  end

  create_table "reminders", force: :cascade do |t|
    t.bigint "asset_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.date "due_date", null: false
    t.string "reminder_type", default: "other", null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_reminders_on_asset_id"
    t.index ["completed_at"], name: "index_reminders_on_completed_at"
    t.index ["status", "due_date"], name: "index_reminders_on_status_and_due_date"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'completed'::character varying]::text[])", name: "chk_reminders_status"
  end

  create_table "service_visits", force: :cascade do |t|
    t.bigint "asset_id", null: false
    t.text "condition_notes"
    t.datetime "created_at", null: false
    t.decimal "engine_hours", precision: 8, scale: 1
    t.boolean "follow_up_needed", default: false, null: false
    t.text "follow_up_notes"
    t.string "location"
    t.bigint "performed_by_user_id", null: false
    t.text "summary"
    t.datetime "updated_at", null: false
    t.date "visit_date", null: false
    t.index ["asset_id"], name: "index_service_visits_on_asset_id"
    t.index ["performed_by_user_id"], name: "index_service_visits_on_performed_by_user_id"
    t.index ["visit_date"], name: "index_service_visits_on_visit_date"
    t.check_constraint "engine_hours IS NULL OR engine_hours >= 0::numeric", name: "chk_service_visits_engine_hours_non_negative"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "role", default: "captain", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "assets", "accounts"
  add_foreign_key "binder_notes", "accounts"
  add_foreign_key "binder_notes", "assets"
  add_foreign_key "contacts", "accounts"
  add_foreign_key "documents", "accounts"
  add_foreign_key "documents", "assets"
  add_foreign_key "reminders", "assets"
  add_foreign_key "service_visits", "assets"
  add_foreign_key "service_visits", "users", column: "performed_by_user_id"
  add_foreign_key "sessions", "users"
end
