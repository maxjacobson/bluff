# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_04_24_052330) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "game_attendances", force: :cascade do |t|
    t.bigint "human_id", null: false
    t.bigint "game_id", null: false
    t.datetime "heartbeat_at", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["game_id"], name: "index_game_attendances_on_game_id"
    t.index ["human_id", "game_id"], name: "index_game_attendances_on_human_id_and_game_id", unique: true
    t.index ["human_id"], name: "index_game_attendances_on_human_id"
  end

  create_table "games", force: :cascade do |t|
    t.string "identifier", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "last_action_at", null: false
    t.index ["identifier"], name: "index_games_on_identifier", unique: true
  end

  create_table "humans", force: :cascade do |t|
    t.string "nickname", null: false
    t.string "uuid", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["uuid"], name: "index_humans_on_uuid", unique: true
  end

  add_foreign_key "game_attendances", "games"
  add_foreign_key "game_attendances", "humans"
end
