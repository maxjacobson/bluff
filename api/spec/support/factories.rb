# frozen_string_literal: true

module Factories
  def create_game(attrs = {})
    Game.create!({
      identifier: Faker::Creature::Animal.name
    }.merge(attrs))
  end

  def create_human(attrs = {})
    Human.create!({
      nickname: 'Joe MacMillan',
      uuid: SecureRandom.uuid
    }.merge(attrs))
  end
end

RSpec.configure do |config|
  config.include(Factories)
end
