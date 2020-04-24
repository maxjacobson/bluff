# frozen_string_literal: true

module Factories
  def create_game(attrs = {})
    Game.create!({
      identifier: Faker::Creature::Animal.name
    }.merge(attrs))
  end
end

RSpec.configure do |config|
  config.include(Factories)
end
