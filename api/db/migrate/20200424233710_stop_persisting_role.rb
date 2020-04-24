# frozen_string_literal: true

# Now that we have [GameAction]s, we don't need this.
class StopPersistingRole < ActiveRecord::Migration[6.0]
  def up
    remove_column :game_attendances, :role
    execute 'drop type attendance_role;'
  end

  def down
    execute <<~SQL
      create type attendance_role as enum (
        'viewer', 'player'
      );
    SQL

    add_column :game_attendances,
               :role,
               :attendance_role,
               default: 'viewer',
               null: false
  end
end
