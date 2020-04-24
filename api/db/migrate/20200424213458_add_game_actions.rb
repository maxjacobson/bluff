# frozen_string_literal: true

# Game Actions are like a stream of events. From the stream, we can figure out
# what happened and what the state of the game is.
class AddGameActions < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      create type game_action as enum (
        'buy_in', -- value = initial chip count
        'draw', -- value = index of card
        'ante', -- value = number of chips ante'd
        'bet', -- value = amount bet (includes initial bets, calls, and raises)
        'check', -- value = null
        'fold', -- value = null
        'resign', -- value = null
        'become_dealer' -- value = null
      );
    SQL

    create_table :game_actions do |t|
      t.references :attendance,
                   null: false,
                   foreign_key: { to_table: :game_attendances }
      t.column :action, :game_action, null: false

      # This is a maybe weird modeling solution, but I'm imaginning that this
      # will represent different things depending on the action (see above)
      t.integer :value, null: true

      t.timestamps
    end
  end

  def down
    drop_table :game_actions

    execute <<~SQL
      drop type game_action;
    SQL
  end
end
