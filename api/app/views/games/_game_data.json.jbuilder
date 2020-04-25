# frozen_string_literal: true

json.id game.identifier
json.status game.status
json.last_action_at Millis.new(game.last_action_at).to_i
json.spectators_count game.recent_spectators_count
json.players game.dealer.current_players,
             partial: 'players/player',
             as: :player,
             locals: { dealer: game.dealer }
json.total_chips_count game.dealer.total_chips_count
