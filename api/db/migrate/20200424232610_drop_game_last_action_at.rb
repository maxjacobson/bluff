# frozen_string_literal: true

# We can derive this from GameAction now
class DropGameLastActionAt < ActiveRecord::Migration[6.0]
  def change
    remove_column :games, :last_action_at
  end
end
