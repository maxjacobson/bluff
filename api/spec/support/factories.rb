# frozen_string_literal: true

def create_game(attrs = {})
  Game.create!({
    identifier: Faker::Creature::Animal.name
  }.merge(attrs))
end
