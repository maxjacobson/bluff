# frozen_string_literal: true

# This is the thing that looks at the stream of [GameAction]s and keeps track
# of the state of the world.
class Dealer
  DEFAULT_ANTE_AMOUNT = 5

  # The people currently playing, in the order they're sitting around the table
  attr_reader :current_players

  # This is how we keep track of which player is the "dealer", which determines
  # who bets first each hand. It should be picked at random for the first hand,
  # and then rotate around the table.
  attr_reader :player_with_dealer_chip

  # How many chips are currently sitting in the middle of the table
  attr_reader :pot_size

  attr_reader :status

  def initialize(game)
    @game = game
    @actions = nil # bust memoization
    @current_players = SortedSet.new
    @players_to_join_next_hand = Set.new
    @players_who_are_out = Set.new
    @current_dealer = nil
    @chip_counts = {}
    # TODO: will need to make sure to clear this whenever a hand ends
    @current_cards = {}
    @pot_size = 0
    @status = GameStatus::PENDING

    visit_actions
  end

  def latest_action_at
    actions.last&.created_at
  end

  def role(human)
    if current_members.include?(human)
      'player'
    else
      'viewer'
    end
  end

  def chip_count_for(human)
    chip_counts.fetch(human.id)
  end

  def current_card_for(human)
    current_cards[human]
  end

  def in_next_hand?(human)
    players_to_join_next_hand.include?(human)
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

  # This is the set of people who are part of the game
  def current_members
    current_players + players_to_join_next_hand + players_who_are_out
  end

  def current_ante_amount_for(_player)
    # FIXME: if the player somehow has fewer than 5 chips, just toss them in,
    #        we'll figure out how to split the pot

    # TODO: As the game goes on, ratchet this up?
    #       Thinking we can keep track of how many hands have been played, and
    #       have some fixed schedule. Or do some math so it scales as a ratio
    #       of the median chips count or something fancy like that. E.g. 1/20th
    #       of median pot size...??

    DEFAULT_ANTE_AMOUNT
  end

  # The player after the dealer draws and bets first
  def current_players_in_dealing_order
    players = current_players.to_a
    (dealer_position = players.index do |player|
      player.id == player_with_dealer_chip.id
    end) || raise
    players.rotate(dealer_position + 1)
  end

  private

  attr_reader :game, :chip_counts, :current_cards, :players_to_join_next_hand,
              :players_who_are_out
  attr_writer :player_with_dealer_chip, :pot_size

  ##### visitor helpers

  # Replay history from beginning to end to figure out where we stand now
  def visit_actions
    actions.each do |action|
      send("on_action_#{action.action}", action)
    end
  end

  def on_action_ante(action)
    # Move the chips from the player to the pot
    self.pot_size += action.value
    chip_counts[action.human.id] -= action.value
  end

  def on_action_become_dealer(action)
    self.player_with_dealer_chip = action.human

    players_to_join_next_hand.to_a.each do |player|
      current_players.add(player)
      players_to_join_next_hand.delete(player)
    end
  end

  def on_action_draw(action)
    @status = GameStatus::PLAYING
    current_cards[action.human] = CardDatabaseValue.to_card(action.value)
  end

  def on_action_buy_in(action)
    players_to_join_next_hand.add(action.human)

    # This human bought in with a certain number of chips
    chip_counts[action.human.id] ||= 0
    chip_counts[action.human.id] += action.value
  end

  #### summarizers

  def summarize_ante_for(action, _current_human)
    "#{action.human.nickname} anted #{plural_chips action.value}"
  end

  def summarize_become_dealer_for(action, _current_human)
    "#{action.human.nickname} received the dealer chip"
  end

  def summarize_buy_in_for(action, _current_human)
    "#{action.human.nickname} joined with #{plural_chips action.value}"
  end

  def summarize_draw_for(action, current_human)
    if action.human == current_human
      'You drew a card'
    else
      "#{action.human.nickname} drew the " \
      "#{CardDatabaseValue.to_card(action.value)}"
    end
  end

  def plural_chips(num)
    "#{num} #{'chip'.pluralize(num)}"
  end
end
