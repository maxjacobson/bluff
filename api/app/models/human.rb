# frozen_string_literal: true

# A human who visited the site, and may or may not have played a game
class Human < ApplicationRecord
  has_many :attendances, class_name: 'GameAttendance'
  has_many :games, through: :attendances

  validates :nickname, presence: true

  # Even if we don't know who they are, we're going to act like we do
  def self.recognize(uuid)
    return if uuid.blank?

    create_with(nickname: RandomNickname.new.to_s).create_or_find_by(uuid: uuid)
  end

  def record_heartbeat(game)
    if (attendance = game.attendances.find_by_human_id(id)).present?
      attendance.heartbeat!
    elsif game.attendances.none?
      # first human auto-buys-in
      game.action_creator.buy_in!(self)
    else
      # other humans are just spectators
      game.attendances.create!(human_id: id)
    end
  end

  def heartbeat_for(game)
    game.attendances.find_by_human_id!(id).heartbeat_at
  end
end
