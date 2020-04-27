# frozen_string_literal: true

# This is the thing that looks at the stream of [GameAction]s and keeps track
# of the state of the world.
class Dealer
  DEFAULT_ANTE_AMOUNT = 5
  DEFAULT_INITIAL_CHIP_AMOUNT = 100
  MIN_PLAYERS = 2 # no fun to play by yourself
  MAX_PLAYERS = 52 # that's all the cards that exist to go around

  # The people currently playing, in the order they're sitting around the table
  attr_reader :current_players

  # This is how we keep track of which player is the "dealer", which determines
  # who bets first each hand. It should be picked at random for the first hand,
  # and then rotate around the table.
  attr_reader :player_with_dealer_chip

  # How many chips are currently sitting in the middle of the table
  attr_reader :pot_size

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

      current_players.each do |player|
        GameAction.create!(
          attendance: attendance_for(player),
          action: 'ante',
          value: current_ante_amount_for(player)
        )
      end

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

  def bet!(amount, player)
    return unless can_bet?(amount, player)

    ApplicationRecord.transaction do
      GameAction.create!(
        attendance: attendance_for(player),
        action: 'bet',
        value: amount
      )
    end
  end

  def next_action
    player = action_to
    return if player.blank?

    attendance = attendance_for(player)
    ante_amount = current_ante_amount_for(player)
    chips = chip_count_for(player)

    {

      player: {
        id: player.id,
        nickname: player.nickname,
        heartbeat_at: Millis.new(attendance.heartbeat_at).to_i,
        role: role(player)
      },
      bet: {
        available: action_to == player,

        # ordinarily you shouldn't be able to bet less than tha ante amount,
        # but if that's all you got, OK
        minimum: [chips, ante_amount].min,
        maximum: chips
      },
      raise: {
        available: false
      },
      call: {
        available: false
      },
      check: {
        available: false
      },
      fold: {
        available: false
      }
    }
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

  def current_card_for(human)
    current_cards[human]
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

  def in_current_hand?(player)
    current_cards.key?(player)
  end

  private

  attr_reader :game, :chip_counts, :current_cards, :action_to
  attr_writer :player_with_dealer_chip, :pot_size, :action_to

  # The player after the dealer draws and bets first
  def current_players_in_dealing_order
    players = current_players.to_a
    (dealer_position = players.index do |player|
      player.id == player_with_dealer_chip.id
    end) || raise
    players.rotate(dealer_position + 1)
  end

  def player_after(human)
    players = current_players.to_a.select { |player| in_current_hand?(player) }
    position = players.index(human)
    players.rotate(position + 1).first
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

  def can_bet?(amount, player)
    chip_count_for(player) >= amount &&
      action_to == player
  end

  def attendance_for(human)
    game.attendances.detect { |a| a.human_id == human.id } || raise
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

  ##### visitor helpers

  def appraise_situation
    @actions = nil # bust memoization
    @current_players = SortedSet.new
    @current_dealer = nil
    @chip_counts = {}
    # TODO: will need to make sure to clear this whenever a hand ends
    @current_cards = {}
    @pot_size = 0
    @action_to = nil

    visit_actions
  end

  alias reappraise_situation appraise_situation

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
    self.action_to = current_players_in_dealing_order.first
  end

  def on_action_bet(action)
    self.pot_size += action.value
    chip_counts[action.human.id] -= action.value

    # FIXME: it's possible that, at this point, the hand is over, if I'm the
    # last player to call a bet that was going around the table. So we need
    # to check if that's the case, and if so, make that clear in the summary
    # and move the money back to that player. Additionally, the dealer chip
    # needs to move, and the action needs to move to the player after the
    # dealer...

    # if hand_is_over?
    #   if game_is_over?

    # else
    #   # that player might be all-in, in which case we need to keep going
    #   self.action_to = player_after(action.human)
    # end

    raise
  end

  def on_action_buy_in(action)
    # This human bought in, seems like they're playing
    current_players.add(action.human)

    # This human bought in with a certain number of chips
    chip_counts[action.human.id] ||= 0
    chip_counts[action.human.id] += action.value
  end

  def on_action_draw(action)
    current_cards[action.human] = CardDatabaseValue.to_card(action.value)
  end

  #### summarizers

  def summarize_ante_for(action, current_human)
    if action.human == current_human
      'You'
    else
      action.human.nickname.to_s
    end + " anted #{plural_chips action.value}"
  end

  def summarize_become_dealer_for(action, current_human)
    if action.human == current_human
      'You'
    else
      action.human.nickname.to_s
    end + ' received the dealer chip'
  end

  def summarize_bet_for(action, current_human)
    if action.human == current_human
      'You'
    else
      action.human.nickname.to_s
    end + " bet #{plural_chips(action.value)}"
  end

  def summarize_buy_in_for(action, current_human)
    if action.human == current_human
      'You'
    else
      action.human.nickname.to_s
    end + " joined with #{plural_chips(action.value)}"
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
