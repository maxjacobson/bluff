# frozen_string_literal: true

# A game represents a particular gathering of humans to play bluff
class Game < ApplicationRecord
  has_many :attendances, class_name: 'GameAttendance'
  has_many :humans, through: :attendances
  has_many :actions, through: :attendances, source: :actions

  enum status: {
    pending: 'pending',
    playing: 'playing',
    complete: 'complete'
  }

  scope :newest_to_oldest, -> { order(created_at: :desc) }

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

  def dealer
    Dealer.new(self)
  end

  def last_action_at
    dealer.latest_action_at || created_at
  end
end
