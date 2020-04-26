# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dealer do
  let(:game) { create_game }
  let(:donna) { create_human(nickname: 'Donna') }
  let(:gordon) { create_human(nickname: 'Gordon') }
  subject(:dealer) { described_class.new(game) }

  describe '#buy_in!' do
    before do
      dealer.buy_in!(gordon)
    end

    context 'when the player has not yet joined' do
      it 'emits an additional action' do
        expect { dealer.buy_in!(donna) }.to change {
                                              GameAction.count
                                            }.from(1).to(2)
      end
    end

    context 'when the player already joined' do
      it 'returns false' do
        expect { dealer.buy_in!(gordon) }.to_not(change { GameAction.count })
      end
    end
  end
end
