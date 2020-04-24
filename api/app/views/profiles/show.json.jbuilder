# frozen_string_literal: true

json.data do
  json.nickname current_human.nickname
  json.games current_human.games.newest_to_oldest,
             partial: 'games/game_data', as: :game
end
