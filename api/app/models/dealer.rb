# frozen_string_literal: true

# This is the thing that looks at the stream of [GameAction]s and keeps track
# of the state of the world.
class Dealer
  # The people currently playing, in the order they're sitting around the table
  attr_reader :current_players

  def initialize(game)
    @game = game
    @current_players ||= SortedSet.new
    @chip_counts ||= {}
    visit_actions
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

  def chip_count_for(human)
    chip_counts.fetch(human.id)
  end

  # Later, will need to figure out how to make sure we count the pot
  def total_chips_count
    chip_counts.values.sum
  end

  private

  attr_reader :game, :chip_counts

  # Replay history from beginning to end to figure out where we stand now
  def visit_actions
    actions.each do |action|
      send("on_action_#{action.action}", action)
    end
  end

  def on_action_buy_in(action)
    # This human bought in, seems like they're playing
    current_players.add(action.human)

    # This human bought in with a certain number of chips
    chip_counts[action.human.id] ||= 0
    chip_counts[action.human.id] += action.value
  end

  def actions
    @actions ||= game.actions.chronological.to_a
  end
end
