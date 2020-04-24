# frozen_string_literal: true

# The thinking here is that we'll want to know the state of the game, which
# will help determine what UI to show, and what actions are allowed.
class AddStatusToGames < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      create type game_status as enum (
        'pending', 'playing', 'complete'
      );
    SQL

    change_table :games do |t|
      t.column :status, :game_status, default: 'pending', null: false
    end
  end

  def down
    remove_column :games, :status

    execute <<~SQL
      drop type game_status;
    SQL
  end
end
