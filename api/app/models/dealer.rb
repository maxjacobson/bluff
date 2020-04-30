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

  # How many chips are currently sitting in the middle of the table, grouped
  # by which player the money came from.
  attr_reader :pot_by_player

  # Returns a [GameStatus]
  attr_reader :status

  # The player whose turn it is to take an action, if any
  # Returns a [Human] or [NilClass]
  attr_reader :action_to

  def initialize(game)
    @game = game
    @actions = nil # bust memoization
    @current_players = SortedSet.new
    @players_to_join_next_hand = Set.new
    @players_who_are_out = Set.new
    @current_dealer = nil
    @chip_counts = {}
    @current_cards = {}
    @pot_by_player = {}
    @status = GameStatus::PENDING
    @action_to = nil

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

  def waiting_for_next_hand?(human)
    players_to_join_next_hand.include?(human)
  end

  def all_out?(human)
    players_who_are_out.include?(human)
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

  def current_ante_amount_for(human)
    # TODO: As the game goes on, ratchet this up?
    #       Thinking we can keep track of how many hands have been played, and
    #       have some fixed schedule. Or do some math so it scales as a ratio
    #       of the median chips count or something fancy like that. E.g. 1/20th
    #       of median pot size...??

    [
      chip_count_for(human),
      DEFAULT_ANTE_AMOUNT
    ].min
  end

  # The player after the dealer draws and bets first
  def current_players_in_dealing_order
    players = current_players.to_a
    (dealer_position = players.index(player_with_dealer_chip)) || raise
    players.rotate(dealer_position + 1)
  end

  def can_bet?(human)
    current_players.include?(human) && chip_count_for(human).positive?
  end

  def minimum_bet(human)
    minimum_bet = [
      current_ante_amount_for(human),
      max_bet_on_table_by_someone_other_than(human)
    ].max

    current_chip_count = chip_count_for(human)

    # You have to match the bet on the table, but if you don't have that many,
    # you can still go all-in. We'll split the pot if you win the hand.
    [
      minimum_bet,
      current_chip_count
    ].min
  end

  def maximum_bet(human)
    chip_count_for(human)
  end

  def can_check?(human)
    return false unless action_to == human

    current_bet = bet_amount_for(human)
    max_bet = max_bet_on_table_by_someone_other_than(human)
    chip_count = chip_count_for(human)

    chip_count.zero? || current_bet == max_bet
  end

  def can_fold?(human)
    # I was tempted to not let you fold unless there's a bet to you, but
    # actually I don't care, if you want to fold, be my guest. Maybe that's
    # how you want to communicate information.

    action_to == human
  end

  def pot_size
    pot_by_player.values.sum
  end

  private

  attr_reader :game, :chip_counts, :current_cards, :players_to_join_next_hand,
              :players_who_are_out
  attr_writer :player_with_dealer_chip, :action_to

  def next_better_after(human)
    players = current_players.to_a
    position = players.index(human)
    players.rotate(position + 1).detect do |potential_better|
      bet_amount_for(human) > bet_amount_for(potential_better) &&
        chip_count_for(potential_better).positive?
    end
  end

  def max_bet_on_table_by_someone_other_than(human)
    max_bet_on_table = 0
    pot_by_player.each do |better, bet|
      max_bet_on_table = bet if bet > max_bet_on_table && better != human
    end
    max_bet_on_table
  end

  def bet_amount_for(player)
    pot_by_player[player] || 0
  end

  ##### visitor helpers

  # Replay history from beginning to end to figure out where we stand now
  def visit_actions
    actions.each do |action|
      send("on_action_#{action.action}", action)
    end
  end

  def on_action_ante(action)
    # Move the chips from the player to the pot
    pot_by_player[action.human] ||= 0
    pot_by_player[action.human] += action.value
    chip_counts[action.human.id] -= action.value
  end

  # If this action happens, it means we're starting a fresh hand
  def on_action_become_dealer(action)
    self.player_with_dealer_chip = action.human

    players_to_join_next_hand.to_a.each do |player|
      current_players.add(player)
      players_to_join_next_hand.delete(player)
    end

    current_cards.clear
    pot_by_player.clear
    self.action_to = current_players_in_dealing_order.first
  end

  def on_action_check(action)
    # just move the action, and if there's no new action, end the hand
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

  def on_action_bet(action)
    chip_counts[action.human.id] -= action.value
    pot_by_player[action.human] ||= 0
    pot_by_player[action.human] += action.value

    # May be setting it to nil
    self.action_to = next_better_after(action.human)

    on_hand_ended if action_to.blank?
  end

  def on_action_fold(action)
    current_cards.delete(action.human)
    current_players.delete(action.human)
    players_to_join_next_hand.add(action.human)
  end

  def on_hand_ended
    # hand is over, need to figure out what to do
    # - divvy up pot
    # - eject some players from the game who are now at zero chips
    # - expose the next dealer via a getter?
    raise
  end

  #### summarizers

  def summarize_ante_for(action, current_human)
    actor = action_summary_actor(action, current_human)
    "#{actor} anted #{plural_chips action.value}"
  end

  def summarize_become_dealer_for(action, current_human)
    actor = action_summary_actor(action, current_human)
    "#{actor} received the dealer chip"
  end

  def summarize_bet_for(action, current_human)
    actor = action_summary_actor(action, current_human)
    "#{actor} bet #{plural_chips action.value}"
  end

  def summarize_buy_in_for(action, current_human)
    actor = action_summary_actor(action, current_human)
    "#{actor} joined with #{plural_chips action.value}"
  end

  def summarize_check_for(action, current_human)
    actor = action_summary_actor(action, current_human)
    "#{actor} checked"
  end

  def summarize_draw_for(action, current_human)
    if action.human == current_human
      'You drew a card'
    else
      "#{action.human.nickname} drew the " \
      "#{CardDatabaseValue.to_card(action.value)}"
    end
  end

  def summarize_fold_for(action, current_human)
    actor = action_summary_actor(action, current_human)
    "#{actor} folded the #{CardDatabaseValue.to_card(action.value)}"
  end

  def action_summary_actor(action, current_human)
    if action.human == current_human
      'You'
    else
      action.human.nickname
    end
  end

  def plural_chips(num)
    "#{num} #{'chip'.pluralize(num)}"
  end
end
