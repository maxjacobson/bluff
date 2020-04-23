# frozen_string_literal: true

# Add the initial shape of the games table that will represent a group's game
class AddGamesTable < ActiveRecord::Migration[6.0]
  def change
    create_table :games do |t|
      t.string :identifier, null: false

      t.timestamps
    end

    add_index :games, [:identifier], unique: true
  end
end
