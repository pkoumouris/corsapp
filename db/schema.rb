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

ActiveRecord::Schema[7.0].define(version: 2023_05_12_011032) do
  create_table "donations", force: :cascade do |t|
    t.integer "amount_in_cents"
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
    t.boolean "recurring"
    t.boolean "imported_to_nb"
    t.datetime "imported_to_nb_at"
    t.boolean "exported"
    t.string "order_id"
    t.string "other_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "generals", force: :cascade do |t|
    t.string "name"
    t.string "value"
    t.boolean "current"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_generals_on_name", unique: true
  end

end
