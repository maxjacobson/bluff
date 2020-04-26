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
  # - Can a player join after the game has ended?
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

  # FIXME: record an action and use that to determine who the current dealer is
  def player_with_dealer_chip
    current_players&.first
  end

  def actions
    @actions ||= game.actions.chronological.to_a
  end

  # Summarize what happened
  # TODO: after implementing cards, make sure not to reveal a player's card to
  # that player (maybe can reveal after hand ends?)
  def summarize_for(action, human)
    send("summarize_#{action.action}_for", action, human)
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

  def summarize_buy_in_for(action, _current_human)
    "#{action.human.nickname} joined with #{action.value} " \
    "#{'chip'.pluralize(action.value)}"
  end
end
