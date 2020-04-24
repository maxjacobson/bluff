# frozen_string_literal: true

# Track who has attended which games. Some will be players, and others
# spectators.
class AddGameAttendance < ActiveRecord::Migration[6.0]
  def change
    create_table :game_attendances do |t|
      t.references :human, null: false, foreign_key: true
      t.references :game, null: false, foreign_key: true
      t.timestamp :heartbeat_at, null: false

      t.timestamps
    end

    add_index :game_attendances, %i[human_id game_id], unique: true
  end
end
