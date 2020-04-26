# frozen_string_literal: true

# This is the thing that looks at the stream of [GameAction]s and keeps track
# of the state of the world.
class Dealer
  DEFAULT_INITIAL_CHIP_AMOUNT = 100
  MIN_PLAYERS = 2 # no fun to play by yourself
  MAX_PLAYERS = 52 # that's all the cards that exist to go around

  # The people currently playing, in the order they're sitting around the table
  attr_reader :current_players

  # This is how we keep track of which player is the "dealer", which determines
  # who bets first each hand. It should be picked at random for the first hand,
  # and then rotate around the table.
  attr_reader :player_with_dealer_chip

  def initialize(game)
    @game = game
    appraise_situation
  end

  def can_become_dealer?(human)
    current_players.include?(human)
  end

  # Records a GameAction of action = 'buy_in'. That action represents a player
  # joining the game and getting their initial stack of chips. There's no
  # actual money involved, this is just for fun.
  def buy_in!(human)
    return unless can_join?(human)

    ApplicationRecord.transaction do
      attendance = game.attendances.create_or_find_by!(human_id: human.id)

      GameAction.create!(
        attendance: attendance,
        action: 'buy_in',
        value: DEFAULT_INITIAL_CHIP_AMOUNT
      )
      reappraise_situation
    end
  end

  def start!(requested_by_human)
    return unless can_start?(requested_by_human)

    ApplicationRecord.transaction do
      game.playing!

      GameAction.create!(
        attendance: attendance_for(current_players.to_a.sample),
        action: 'become_dealer'
      )
      reappraise_situation

      deck = DeckOfCards.new.shuffle

      current_players_in_dealing_order.each do |player|
        GameAction.create!(
          attendance: attendance_for(player),
          action: 'draw',
          value: deck.draw.to_i
        )
      end
      reappraise_situation
    end
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

  attr_reader :game, :chip_counts, :current_cards
  attr_writer :player_with_dealer_chip

  # The player after the dealer draws and bets first
  def current_players_in_dealing_order
    players = current_players.to_a
    (dealer_position = players.index do |player|
      player.id == player_with_dealer_chip.id
    end) || raise
    players.rotate(dealer_position + 1)
  end

  # Policy about who can start the game and when
  def can_start?(human)
    current_players.include?(human) &&
      current_players.count >= MIN_PLAYERS &&
      game.pending?
  end

  # Some nuances to consider later:
  #
  # - Can a player re-join after resigning?
  # - Should there be a lower ceiling on players?
  # - Can a player join after the game has ended?
  def can_join?(human)
    current_players.exclude?(human) &&
      current_players.count < MAX_PLAYERS
  end

  def attendance_for(human)
    game.attendances.detect { |a| a.human_id == human.id } || raise
  end

  ##### visitor helpers

  def appraise_situation
    @actions = nil # bust memoization
    @current_players = SortedSet.new
    @current_dealer = nil
    @chip_counts = {}
    # TODO: will need to make sure to clear this whenever a hand ends
    @current_cards = {}

    visit_actions
  end

  alias reappraise_situation appraise_situation

  # Replay history from beginning to end to figure out where we stand now
  def visit_actions
    actions.each do |action|
      send("on_action_#{action.action}", action)
    end
  end

  def on_action_become_dealer(action)
    self.player_with_dealer_chip = action.human
  end

  def on_action_draw(action)
    current_cards[action.human] = CardDatabaseValue.to_card(action.value)
  end

  def on_action_buy_in(action)
    # This human bought in, seems like they're playing
    current_players.add(action.human)

    # This human bought in with a certain number of chips
    chip_counts[action.human.id] ||= 0
    chip_counts[action.human.id] += action.value
  end

  #### summarizers

  def summarize_become_dealer_for(action, _current_human)
    "#{action.human.nickname} received the dealer chip"
  end

  def summarize_buy_in_for(action, _current_human)
    "#{action.human.nickname} joined with #{action.value} " \
    "#{'chip'.pluralize(action.value)}"
  end

  def summarize_draw_for(action, current_human)
    if action.human == current_human
      'You drew a card'
    else
      "#{action.human.nickname} drew the " \
      "#{CardDatabaseValue.to_card(action.value)}"
    end
  end
end
