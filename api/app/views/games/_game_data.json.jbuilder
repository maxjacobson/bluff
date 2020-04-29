# frozen_string_literal: true

json.id game.identifier
json.status game.dealer.status
json.last_action_at Millis.new(game.last_action_at).to_i
json.current_dealer_id game.dealer.player_with_dealer_chip&.id
json.players game.dealer.current_members,
             partial: 'players/player',
             as: :player,
             locals: { dealer: game.dealer }

json.actions game.dealer.actions.reverse,
             partial: 'games/action',
             as: :action,
             locals: { dealer: game.dealer }
json.pot_size game.dealer.pot_size
