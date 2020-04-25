# frozen_string_literal: true

# Make it easier to prune old data by letting us just delete a game, and know
# that associated records will also get deleted automatically.
class GameAttendanceCascadingDeletes < ActiveRecord::Migration[6.0]
  def change
    remove_foreign_key :game_attendances, :games
    add_foreign_key :game_attendances, :games, on_delete: :cascade

    remove_foreign_key :game_actions, :game_attendances, column: :attendance_id
    add_foreign_key :game_actions,
                    :game_attendances,
                    on_delete: :cascade,
                    column: :attendance_id
  end
end
