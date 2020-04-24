# frozen_string_literal: true

json.data do
  json.id @game.identifier
  json.players_count 4
  json.spectators_count 5
end

json.meta do
  if current_human.present?
    json.human do
      json.nickname current_human.nickname
    end
  end
end
