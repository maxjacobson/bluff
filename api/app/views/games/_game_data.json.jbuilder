# frozen_string_literal: true

dealer = game.dealer

json.id game.identifier
json.status dealer.status
json.last_action_at Millis.new(game.last_action_at).to_i
json.current_dealer_id dealer.player_with_dealer_chip&.id
json.players dealer.current_members,
             partial: 'players/player',
             as: :player,
             locals: { dealer: dealer }

json.actions dealer.actions.reverse,
             partial: 'games/action',
             as: :action,
             locals: { dealer: dealer }
json.pot_size dealer.pot_size

json.next_action do
  json.partial! 'games/next_action', locals: { dealer: dealer, game: game }
end
