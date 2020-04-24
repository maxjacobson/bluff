# frozen_string_literal: true

# We're going to need to keep track of which humans who visit a game are
# actually playing.
class AddAttendanceRole < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      create type attendance_role as enum (
        'viewer', 'player'
      );
    SQL

    change_table :game_attendances do |t|
      t.column :role, :attendance_role, default: 'viewer', null: false
    end
  end

  def down
    remove_column :game_attendances, :role

    execute <<~SQL
      drop type attendance_role;
    SQL
  end
end
