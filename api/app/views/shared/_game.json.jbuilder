# frozen_string_literal: true

json.data do
  json.partial! 'games/game_data', game: game
end

json.meta do
  if current_human.present?
    json.human do
      json.nickname current_human.nickname
      json.heartbeat_at Millis.new(current_human.heartbeat_for(game)).to_i
      json.role game.dealer.role(current_human)
    end
  end
end
