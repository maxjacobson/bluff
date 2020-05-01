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
    @chip_counts = {}
    @current_cards = {}
    @pot_by_player = {}
    @action_amounts = {}
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
    chip_counts.fetch(human)
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
    @actions ||= game.actions.chronological.includes([:human]).to_a
  end

  # Summarize what happened
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
    current_bet = bet_amount_for(human)
    minimum_bet = max_bet_on_table_by_someone_other_than(human) - current_bet
    minimum_bet = 1 if minimum_bet.zero? # zero isn't a bet

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

  def bet_amount_for(player)
    pot_by_player[player] || 0
  end

  private

  attr_reader :game, :chip_counts, :current_cards, :players_to_join_next_hand,
              :players_who_are_out

  # how much had the player put in when they last checked, or bet.
  # Or, how much were they faced with putting in if they folded.
  attr_reader :action_amounts
  attr_writer :player_with_dealer_chip, :action_to

  # def next_better_after(human)
  #   players = current_players.to_a
  #   position = players.index(human)
  #   players.rotate(position + 1).detect do |potential_better|
  #     bet_amount_for(human) > bet_amount_for(potential_better) &&
  #       chip_count_for(potential_better).positive?
  #   end
  # end

  # def next_checker_after(human, human_checked_at)
  #   players = current_players.to_a
  #   position = players.index(human)
  #   players.rotate(position + 1).detect do |potential_checker|
  #     action_amount_for(potential_checker).nil? ||
  #       action_amount_for(potential_checker) < human_checked_at &&
  #         chip_count_for(potential_checker).positive?
  #   end
  # end

  def next_player_that_can_act(human)
    players = current_players.to_a
    position = players.index(human)
    players.rotate(position + 1).detect do |potential_actor|
      next if human == potential_actor

      bet_to_match = max_bet_on_table_by_someone_other_than(potential_actor)

      # Is this exhaustive?
      (bet_to_match > bet_amount_for(potential_actor) ||
        action_amount_for(potential_actor).nil? ||
        action_amount_for(potential_actor) < action_amount_for(human)) &&
        chip_count_for(potential_actor).positive?
    end
  end

  def max_bet_on_table_by_someone_other_than(human)
    max_bet_on_table = 0
    pot_by_player.each do |better, bet|
      max_bet_on_table = bet if bet > max_bet_on_table && better != human
    end
    max_bet_on_table
  end

  def action_amount_for(player)
    action_amounts[player]
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
    chip_counts[action.human] -= action.value
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
    action_amounts.clear
    self.action_to = current_players_in_dealing_order.first
  end

  def on_action_check(action)
    action_amounts[action.human] = bet_amount_for(action.human)
    self.action_to = next_player_that_can_act(action.human)

    on_hand_ended if action_to.blank?
  end

  def on_action_draw(action)
    @status = GameStatus::PLAYING
    current_cards[action.human] = CardDatabaseValue.to_card(action.value)
  end

  def on_action_buy_in(action)
    players_to_join_next_hand.add(action.human)

    # This human bought in with a certain number of chips
    chip_counts[action.human] ||= 0
    chip_counts[action.human] += action.value
  end

  def on_action_bet(action)
    chip_counts[action.human] -= action.value
    pot_by_player[action.human] ||= 0
    pot_by_player[action.human] += action.value
    action_amounts[action.human] = bet_amount_for(action.human)

    self.action_to = next_player_that_can_act(action.human)
    on_hand_ended if action_to.blank?
  end

  def on_action_fold(action)
    action_amounts[action.human] =
      max_bet_on_table_by_someone_other_than(action.human)
    self.action_to = next_player_that_can_act(action.human)
    current_cards.delete(action.human)
    current_players.delete(action.human)
    players_to_join_next_hand.add(action.human)
    self.action_to = nil if current_players.count == 1
    on_hand_ended if action_to.blank?
  end

  def on_hand_ended
    divvy_up_pot

    # Perhaps odd to do this on hand end, and then again on hand begin...
    players_to_join_next_hand.each do |player|
      current_players.add(player)
    end

    current_players.to_a.each do |player|
      if chip_count_for(player).zero?
        current_players.delete(player)
        players_who_are_out.add(player)
      end
    end

    if current_players.count == 1
      @status = GameStatus::COMPLETE
      self.player_with_dealer_chip = nil
    else
      self.player_with_dealer_chip = current_players_in_dealing_order.first
    end
  end

  def divvy_up_pot
    loop do
      values_in_pot = pot_by_player.values.uniq.sort

      largest_amount = values_in_pot[-1]
      second_largest_amount = values_in_pot[-2] || 0

      at_stake_per_player_with_this_much_in_pot_for_this_split_pot =
        largest_amount - second_largest_amount

      player_with_best_hand = nil
      winnings = 0
      pot_by_player.each do |player, amount|
        next unless amount == largest_amount

        if current_players.include?(player) &&
           (
              player_with_best_hand.nil? ||
             better_hand?(player, player_with_best_hand)
            )

          player_with_best_hand = player
        end

        winnings +=
          at_stake_per_player_with_this_much_in_pot_for_this_split_pot
        pot_by_player[player] -=
          at_stake_per_player_with_this_much_in_pot_for_this_split_pot
      end

      chip_counts[player_with_best_hand] += winnings

      break if pot_by_player.values.sum.zero?
    end
  end

  def better_hand?(player, other_player)
    card = current_card_for(player)
    other_card = current_card_for(other_player)
    card.better_than?(other_card)
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
