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

ActiveRecord::Schema[7.0].define(version: 2023_07_26_023308) do
  create_table "donations", force: :cascade do |t|
    t.integer "amount_in_cents"
    t.string "gateway_response_code"
    t.string "origin_ip"
    t.string "currency"
    t.boolean "success"
    t.string "bank_transaction_spid"
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.string "tracking_code_slug"
    t.string "tracking_code"
    t.string "address"
    t.string "phone_number"
    t.boolean "send_email_updates"
    t.string "campaign"
    t.string "campaign_name"
    t.boolean "imported_to_nb"
    t.datetime "imported_to_nb_at"
    t.boolean "exported"
    t.string "order_spid"
    t.string "gnaf_address_identifier"
    t.string "other_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "recurring_id"
    t.string "nbid"
    t.boolean "is_recurring"
    t.boolean "test"
    t.string "signup_nbid"
    t.boolean "refunded"
    t.datetime "refunded_at"
    t.string "page_slug"
    t.boolean "is_subsequent_recurring"
    t.integer "expiry_month"
    t.integer "expiry_year"
    t.datetime "executed_at"
    t.index ["bank_transaction_spid"], name: "index_donations_on_bank_transaction_spid"
    t.index ["created_at"], name: "index_donations_on_created_at"
    t.index ["email"], name: "index_donations_on_email"
    t.index ["exported"], name: "index_donations_on_exported"
    t.index ["gateway_response_code"], name: "index_donations_on_gateway_response_code"
    t.index ["imported_to_nb"], name: "index_donations_on_imported_to_nb"
    t.index ["nbid"], name: "index_donations_on_nbid"
    t.index ["order_spid"], name: "index_donations_on_order_spid"
    t.index ["recurring_id"], name: "index_donations_on_recurring_id"
    t.index ["success"], name: "index_donations_on_success"
    t.index ["tracking_code"], name: "index_donations_on_tracking_code"
  end

  create_table "generals", force: :cascade do |t|
    t.string "name"
    t.string "value"
    t.boolean "current"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_generals_on_name", unique: true
  end

  create_table "recurrings", force: :cascade do |t|
    t.string "customer_code"
    t.string "schedule_spid"
    t.integer "amount"
    t.boolean "active"
    t.string "last_digits"
    t.integer "expiry_month"
    t.integer "expiry_year"
    t.string "card_scheme"
    t.string "payment_interval_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "test"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "role"
    t.integer "status"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "donations", "recurrings"
end
