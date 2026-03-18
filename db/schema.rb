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

ActiveRecord::Schema[8.1].define(version: 2026_02_03_202748) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
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

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "angas", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id", "filename"], name: "index_angas_on_user_id_and_filename", unique: true
    t.index ["user_id"], name: "index_angas_on_user_id"
  end

  create_table "bookmarks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "anga_id", null: false
    t.text "cache_error"
    t.datetime "cached_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["anga_id"], name: "index_bookmarks_on_anga_id"
  end

  create_table "identities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["provider", "uid"], name: "index_identities_on_provider_and_uid", unique: true
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "metas", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "anga_filename", null: false
    t.uuid "anga_id"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.boolean "orphan", default: false, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["anga_id"], name: "index_metas_on_anga_id"
    t.index ["user_id", "filename"], name: "index_metas_on_user_id_and_filename", unique: true
    t.index ["user_id"], name: "index_metas_on_user_id"
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.boolean "incidental_password", default: false, null: false
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "versions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.string "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "words", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "anga_id", null: false
    t.datetime "created_at", null: false
    t.text "extract_error"
    t.datetime "extracted_at"
    t.string "source_type", null: false
    t.datetime "updated_at", null: false
    t.index ["anga_id"], name: "index_words_on_anga_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "angas", "users"
  add_foreign_key "bookmarks", "angas"
  add_foreign_key "identities", "users"
  add_foreign_key "metas", "angas", on_delete: :nullify
  add_foreign_key "metas", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "words", "angas"
end
