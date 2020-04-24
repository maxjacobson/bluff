# frozen_string_literal: true

json.id game.identifier
json.status game.status
json.last_action_at game.last_action_at.to_i * 1000
json.spectators_count game.recent_spectators_count
