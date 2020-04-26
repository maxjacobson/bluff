# frozen_string_literal: true

json.data do
  json.nickname current_human.nickname
  json.games current_human.games.sort_by(&:last_action_at).reverse,
             partial: 'games/game_data', as: :game
end
