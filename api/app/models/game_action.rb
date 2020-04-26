# frozen_string_literal: true

# An action taken by a human at a game. This is the source of truth.
class GameAction < ApplicationRecord
  belongs_to :attendance, class_name: 'GameAttendance'
  has_one :game, through: :attendance
  has_one :human, through: :attendance

  enum action: {
    buy_in: 'buy_in',
    draw: 'draw',
    ante: 'ante',
    bet: 'bet',
    check: 'check',
    fold: 'fold',
    resign: 'resign',
    become_dealer: 'become_dealer'
  }

  scope :chronological, -> { order(created_at: :asc) }
end
