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

ActiveRecord::Schema[8.1].define(version: 2026_07_12_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_memberships", force: :cascade do |t|
    t.string "access_level", default: "read_only", null: false
    t.bigint "account_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id"], name: "index_account_memberships_on_account_id"
    t.index ["active"], name: "index_account_memberships_on_active"
    t.index ["user_id", "account_id"], name: "index_account_memberships_on_user_id_and_account_id", unique: true
    t.index ["user_id"], name: "index_account_memberships_on_user_id"
    t.check_constraint "access_level::text = ANY (ARRAY['read_only'::character varying, 'editor'::character varying]::text[])", name: "chk_account_memberships_access_level"
  end

  create_table "accounts", force: :cascade do |t|
    t.string "account_type", default: "client", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.string "time_zone", default: "America/Los_Angeles", null: false
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

  create_table "asset_batteries", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "asset_id", null: false
    t.string "battery_type"
    t.datetime "created_at", null: false
    t.string "location"
    t.string "name", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.index ["asset_id", "active"], name: "index_asset_batteries_on_asset_id_and_active"
    t.index ["asset_id"], name: "index_asset_batteries_on_asset_id"
    t.index ["name"], name: "index_asset_batteries_on_name"
  end

  create_table "asset_engines", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "asset_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_asset_engines_on_active"
    t.index ["asset_id", "position"], name: "index_asset_engines_on_asset_id_and_position"
    t.index ["asset_id"], name: "index_asset_engines_on_asset_id"
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

  create_table "service_visit_battery_checks", force: :cascade do |t|
    t.bigint "asset_battery_id", null: false
    t.boolean "checked", default: false, null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.bigint "service_visit_id", null: false
    t.datetime "updated_at", null: false
    t.decimal "voltage", precision: 6, scale: 2
    t.index ["asset_battery_id"], name: "index_service_visit_battery_checks_on_asset_battery_id"
    t.index ["service_visit_id", "asset_battery_id"], name: "idx_visit_battery_checks_unique_battery", unique: true
    t.index ["service_visit_id"], name: "index_service_visit_battery_checks_on_service_visit_id"
    t.check_constraint "voltage IS NULL OR voltage >= 0::numeric", name: "chk_service_visit_battery_checks_voltage_non_negative"
  end

  create_table "service_visit_engine_readings", force: :cascade do |t|
    t.bigint "asset_engine_id", null: false
    t.datetime "created_at", null: false
    t.decimal "hours", precision: 8, scale: 1
    t.bigint "service_visit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_engine_id"], name: "index_service_visit_engine_readings_on_asset_engine_id"
    t.index ["service_visit_id", "asset_engine_id"], name: "idx_visit_engine_readings_unique_engine", unique: true
    t.index ["service_visit_id"], name: "index_service_visit_engine_readings_on_service_visit_id"
    t.check_constraint "hours IS NULL OR hours >= 0::numeric", name: "chk_service_visit_engine_readings_hours_non_negative"
  end

  create_table "service_visit_inspection_checks", force: :cascade do |t|
    t.boolean "checked", default: false, null: false
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.text "notes"
    t.integer "position", default: 0, null: false
    t.bigint "service_visit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["service_visit_id", "position"], name: "idx_visit_inspection_checks_position"
    t.index ["service_visit_id"], name: "index_service_visit_inspection_checks_on_service_visit_id"
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

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "cancel_at_period_end", default: false, null: false
    t.datetime "canceled_at"
    t.datetime "created_at", null: false
    t.datetime "current_period_ends_at"
    t.string "external_customer_id"
    t.string "external_subscription_id"
    t.datetime "last_synced_at"
    t.string "plan", default: "legacy", null: false
    t.string "provider", default: "local", null: false
    t.string "status", default: "active", null: false
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_subscriptions_on_account_id", unique: true
    t.index ["provider", "external_customer_id"], name: "index_subscriptions_on_provider_and_external_customer_id", where: "(external_customer_id IS NOT NULL)"
    t.index ["provider", "external_subscription_id"], name: "index_subscriptions_on_provider_and_external_subscription_id", unique: true, where: "(external_subscription_id IS NOT NULL)"
    t.check_constraint "plan::text = ANY (ARRAY['legacy'::character varying, 'starter'::character varying, 'professional'::character varying]::text[])", name: "chk_subscriptions_plan"
    t.check_constraint "status::text = ANY (ARRAY['legacy'::character varying, 'trialing'::character varying, 'active'::character varying, 'past_due'::character varying, 'canceled'::character varying, 'expired'::character varying, 'suspended'::character varying]::text[])", name: "chk_subscriptions_status"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "invitation_accepted_at"
    t.datetime "invitation_sent_at"
    t.string "name"
    t.string "password_digest"
    t.string "role", default: "captain", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_users_on_active"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "account_memberships", "accounts"
  add_foreign_key "account_memberships", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "asset_batteries", "assets"
  add_foreign_key "asset_engines", "assets"
  add_foreign_key "assets", "accounts"
  add_foreign_key "binder_notes", "accounts"
  add_foreign_key "binder_notes", "assets"
  add_foreign_key "contacts", "accounts"
  add_foreign_key "documents", "accounts"
  add_foreign_key "documents", "assets"
  add_foreign_key "reminders", "assets"
  add_foreign_key "service_visit_battery_checks", "asset_batteries"
  add_foreign_key "service_visit_battery_checks", "service_visits"
  add_foreign_key "service_visit_engine_readings", "asset_engines"
  add_foreign_key "service_visit_engine_readings", "service_visits"
  add_foreign_key "service_visit_inspection_checks", "service_visits"
  add_foreign_key "service_visits", "assets"
  add_foreign_key "service_visits", "users", column: "performed_by_user_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "subscriptions", "accounts"
end
