# frozen_string_literal: true

# A human who visited the site, and may or may not have played a game
class Human < ApplicationRecord
  has_many :attendances, class_name: 'GameAttendance'
  has_many :games, through: :attendances

  # Even if we don't know who they are, we're going to act like we do
  def self.recognize(uuid)
    return if uuid.blank?

    find_by_uuid(uuid) || create!(
      uuid: uuid,
      nickname: RandomNickname.new.to_s
    )
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

  def join_as_player(game)
    attendance = game.attendances.create_or_find_by!(human_id: id)
    attendance.player!
  end

  def attendance_role_for(game)
    attendance = game.attendances.create_or_find_by!(human_id: id)
    attendance.role
  end
end
