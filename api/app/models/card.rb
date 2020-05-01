# frozen_string_literal: true

Card = Struct.new(:rank, :suit)

# value object that represents a playing card
class Card
  # Lowest value to highest
  SUITS = %i[
    diamonds
    clubs
    hearts
    spades
  ].freeze

  # Lowest rank to highest
  RANKS = %i[
    two
    three
    four
    five
    six
    seven
    eight
    nine
    ten
    jack
    queen
    king
    ace
  ].freeze

  def initialize(rank, suit)
    super(rank, suit)

    raise ArgumentError, "Invalid rank: #{rank}" unless rank.in?(RANKS)
    raise ArgumentError, "Invalid suit: #{suit}" unless suit.in?(SUITS)
  end

  def to_s
    "#{rank.capitalize} of #{suit.capitalize}"
  end

  def to_i
    CardDatabaseValue.new(self).to_i
  end

  def better_than?(other)
    to_i > other.to_i
  end

  protected

  def <=>(other)
    comparable_value <=> other.comparable_value
  end

  def comparable_value
    [
      RANKS.index(rank),
      SUITS.index(suit)
    ]
  end
end
