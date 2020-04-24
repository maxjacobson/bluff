# frozen_string_literal: true

json.data do
  json.partial! 'games/game_data', game: game
end

json.meta do
  if current_human.present?
    json.human do
      json.nickname current_human.nickname
      json.heartbeat_at current_human.heartbeat_for(game).to_i * 1000
      json.role current_human.attendance_role_for(game)
    end
  end
end
