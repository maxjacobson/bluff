# frozen_string_literal: true

# Each time we need to deal a hand, we generate a fresh deck of cards and throw
# the old one into the ocean.
class DeckOfCards
  EmptyDeck = Class.new(StandardError)

  delegate :count, to: :cards

  def shuffle
    cards.shuffle!
    self
  end

  def draw
    cards.shift || raise(EmptyDeck)
  end

  private

  def cards
    @cards ||= Card::SUITS.each_with_object([]) do |suit, deck|
      Card::RANKS.each do |rank|
        deck << Card.new(rank, suit)
      end
    end
  end
end
