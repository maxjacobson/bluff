# frozen_string_literal: true

# A human who visited the site, and may or may not have played a game
class Human < ApplicationRecord
  class << self
    def recognize(uuid)
      return if uuid.blank?

      find_by_uuid(uuid) || create!(
        uuid: uuid,
        nickname: random_nickname
      )
    end

    private

    def random_nickname
      [Faker::Hipster.word, Faker::Creature::Animal.name].join(' ').titlecase
    end
  end
end
