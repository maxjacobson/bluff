# frozen_string_literal: true

RSpec.describe DeckOfCards do
  describe '#draw' do
    it 'returns a card' do
      deck = DeckOfCards.new
      expect(deck.count).to eq(52)
      card = deck.draw
      expect(card).to be_a Card
      expect(deck.count).to eq(51)
    end

    it 'raises when the deck is empty' do
      deck = DeckOfCards.new
      52.times do
        deck.draw
      end

      expect { deck.draw }.to raise_error(DeckOfCards::EmptyDeck)
    end
  end

  describe '#shuffle' do
    it 'returns self' do
      expect(DeckOfCards.new.shuffle).to be_a DeckOfCards
    end
  end
end
