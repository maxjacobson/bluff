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

  def record_heartbeat(game)
    if (attendance = game.attendances.find_by_human_id(id)).present?
      attendance.heartbeat!
    else
      game.attendances.create!(human_id: id)
    end
  end

  def heartbeat_for(game)
    game.attendances.find_by_human_id!(id).heartbeat_at
  end
end
