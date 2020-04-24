# frozen_string_literal: true

# A game represents a particular gathering of humans to play bluff
class Game < ApplicationRecord
  has_many :attendances, class_name: 'GameAttendance'
  has_many :humans, through: :attendances

  before_create -> { self.last_action_at = Time.zone.now }

  def recent_spectators_count
    humans
      .where("game_attendances.heartbeat_at > now() - interval '10 minutes'")
      .count
  end
end
