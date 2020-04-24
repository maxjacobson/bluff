# frozen_string_literal: true

# This records that a human attended a game, either as a player or a spectator.
# This is a join table.
class GameAttendance < ApplicationRecord
  belongs_to :human
  belongs_to :game

  enum role: {
    viewer: 'viewer',
    player: 'player'
  }

  before_create -> { self.heartbeat_at = Time.zone.now }

  # Record that the human is still at the game
  def heartbeat!
    touch(:heartbeat_at)
  end
end
