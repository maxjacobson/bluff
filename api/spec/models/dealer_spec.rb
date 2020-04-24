# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dealer do
  let(:game) { create_game }
  let(:donna) { create_human(nickname: 'Donna') }
  let(:gordon) { create_human(nickname: 'Gordon') }
  subject(:dealer) { described_class.new(game) }

  describe '#can_join?' do
    before do
      GameAction::BuyIn.new(gordon, game).record
    end

    context 'when the player has not yet joined' do
      it 'returns true' do
        expect(dealer.can_join?(donna)).to be true
      end
    end

    context 'when the player already joined' do
      it 'returns false' do
        expect(dealer.can_join?(gordon)).to be false
      end
    end
  end
end
