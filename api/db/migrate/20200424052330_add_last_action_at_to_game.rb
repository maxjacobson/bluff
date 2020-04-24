# frozen_string_literal: true

# We'll track when a game last had an activity (e.g. a bet), which will help us
# come up with a smart polling strategy on the front-end: when people are
# actively playing, we'll poll for updates more frequently.
class AddLastActionAtToGame < ActiveRecord::Migration[6.0]
  def up
    add_column :games, :last_action_at, :timestamp, null: true

    execute 'update games set last_action_at = created_at'

    change_column_null :games, :last_action_at, false
  end

  def down
    remove_column :games, :last_action_at
  end
end
