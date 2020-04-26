# frozen_string_literal: true

# When a player draws a card, we need to record that to the database. Each card
# has a distinct integer to identify it. This class helps map between that
# integer and Card objects.
#
# Higher integers are better cards.
class CardDatabaseValue
  ALL = Card::SUITS
        .product(Card::RANKS)
        .map { |suit, rank| Card.new(rank, suit) }
        .sort
        .each_with_object({})
        .with_index { |(card, obj), index| obj[card] = index }
        .freeze

  ALL_INVERTED = ALL.invert.freeze

  def initialize(card)
    @card = card
  end

  def self.to_card(db_value)
    ALL_INVERTED.fetch(db_value)
  end

  def to_i
    ALL.fetch(card)
  end

  private

  attr_reader :card
end
