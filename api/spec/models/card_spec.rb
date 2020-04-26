# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Card do
  describe '.new' do
    it 'allows good inputs' do
      expect { Card.new(:two, :hearts) }.to_not raise_error
    end

    it 'rejects bad values' do
      expect { Card.new(:two, :dogs) }.to raise_error ArgumentError
    end
  end

  describe '#to_s' do
    it 'returns a human readable representation of the card' do
      card = Card.new(:four, :spades)

      expect(card.to_s).to eq('Four of Spades')
    end
  end

  describe '#to_i' do
    it 'returns a consistent integer for each card' do
      expect(Card.new(:two, :diamonds).to_i).to eq(0)
      expect(Card.new(:two, :clubs).to_i).to eq(1)
      expect(Card.new(:ace, :hearts).to_i).to eq(50)
      expect(Card.new(:ace, :spades).to_i).to eq(51)
    end
  end
end
