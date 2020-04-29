# frozen_string_literal: true

# Basically I determined we don't need this, like all other info we can infer
# it from the stream of actions
class RemoveGameStatus < ActiveRecord::Migration[6.0]
  def up
    remove_column :games, :status

    execute <<~SQL
      drop type game_status;
    SQL
  end

  def down
    execute <<~SQL
      create type game_status as enum (
        'pending', 'playing', 'complete'
      );
    SQL

    change_table :games do |t|
      t.column :status, :game_status, default: 'pending', null: false
    end
  end
end
