# frozen_string_literal: true

# Creates [GameAction]s, collaborating with the [Dealer] to only permit valid
# actions to occur based on the current state of the game
class GameActionCreator
  DEFAULT_INITIAL_CHIP_AMOUNT = 100
  MIN_PLAYERS = 2 # no fun to play by yourself
  MAX_PLAYERS = 52 # that's all the cards that exist to go around

  def initialize(game)
    @game = game
  end

  def bet!(amount, human)
    return unless can_bet?(amount, human)

    ApplicationRecord.transaction do
      attendance = game.attendance_for(human)

      GameAction.create!(
        attendance: attendance,
        action: 'bet',
        value: amount
      )
    end
  end

  # Records a GameAction of action = 'buy_in'. That action represents a player
  # joining the game and getting their initial stack of chips. There's no
  # actual money involved, this is just for fun.
  def buy_in!(human)
    return unless can_buy_in?(human)

    ApplicationRecord.transaction do
      attendance = game.attendances.create_or_find_by!(human_id: human.id)

      GameAction.create!(
        attendance: attendance,
        action: 'buy_in',
        value: DEFAULT_INITIAL_CHIP_AMOUNT
      )
    end
  end

  def start!(requested_by_human)
    return unless can_start?(requested_by_human)

    dealer = Dealer.new(game)

    ApplicationRecord.transaction do
      GameAction.create!(
        attendance: game.attendance_for(dealer.current_members.to_a.sample),
        action: 'become_dealer'
      )

      dealer = Dealer.new(game)

      dealer.current_players.each do |player|
        GameAction.create!(
          attendance: game.attendance_for(player),
          action: 'ante',
          value: dealer.current_ante_amount_for(player)
        )
      end

      deck = DeckOfCards.new.shuffle

      dealer.current_players_in_dealing_order.each do |player|
        GameAction.create!(
          attendance: game.attendance_for(player),
          action: 'draw',
          value: deck.draw.to_i
        )
      end
    end
  end

  private

  attr_reader :game

  def can_bet?(amount, human)
    dealer = Dealer.new(game)
    min = dealer.minimum_bet(human)
    max = dealer.maximum_bet(human)

    amount >= min && amount <= max && dealer.action_to == human
  end

  # Some nuances to consider later:
  #
  # - Can a player re-join after resigning?
  # - Should there be a lower ceiling on players?
  # - Can a player join after the game has ended?
  def can_buy_in?(human)
    current_members = Dealer.new(game).current_members

    current_members.exclude?(human) &&
      current_members.count < MAX_PLAYERS
  end

  # Policy about who can start the game and when
  def can_start?(human)
    dealer = Dealer.new(game)
    current_players = dealer.current_members

    current_players.include?(human) &&
      current_players.count >= MIN_PLAYERS &&
      dealer.status.pending?
  end
end
