# frozen_string_literal: true

# A game represents a particular gathering of humans to play bluff
class Game < ApplicationRecord
  has_many :attendances, class_name: 'GameAttendance'
  has_many :humans, through: :attendances

  enum status: {
    pending: 'pending',
    playing: 'playing',
    complete: 'complete'
  }

  before_create -> { self.last_action_at = Time.zone.now }

  def self.available_identifier
    count = 0
    loop do
      return SecureRandom.uuid if count > 100

      identifier = RandomGameIdentifier.new.to_s
      return identifier unless Game.exists?(identifier: identifier)

      count += 1
    end
  end

  def recent_spectators_count
    humans
      .where("game_attendances.heartbeat_at > now() - interval '10 minutes'")
      .count
  end
end
