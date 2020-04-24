# frozen_string_literal: true

# This is the thing that looks at the stream of [GameAction]s and keeps track
# of the state of the world.
class Dealer
  def initialize(game)
    @game = game
  end

  # Some nuances to consider later:
  #
  # - Can a player re-join after resigning?
  # - Should there be a ceiling on players?
  def can_join?(human)
    current_players.exclude?(human)
  end

  def latest_action_at
    actions.last&.created_at
  end

  def role(human)
    if current_players.include?(human)
      'player'
    else
      'viewer'
    end
  end

  def total_chips_count
    actions.inject(0) do |sum, action|
      if action.buy_in?
        sum + action.value
      else
        sum
      end
    end
  end

  private

  attr_reader :game

  def actions
    @actions ||= game.actions.chronological.to_a
  end

  def current_players
    actions.each_with_object(Set.new) do |action, set|
      set.add(action.human) if action.buy_in?
    end
  end
end
