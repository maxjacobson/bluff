# frozen_string_literal: true

# Introduce the concept of a human, which is just a person who visits the site.
# There won't be any login, but we do need to keep track of individuals so we
# know who has which cards, etc.
class AddHumans < ActiveRecord::Migration[6.0]
  def change
    create_table :humans do |t|
      # I'm thinking we can generate a random cute nickname and let humans
      # override it if they want
      t.string :nickname, null: false

      # something to identify them in the session
      t.string :uuid, null: false

      t.timestamps
    end

    add_index :humans, [:uuid], unique: true
  end
end
