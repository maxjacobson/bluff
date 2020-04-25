# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProfilesController do
  render_views

  describe '#show' do
    let(:uuid) { 'halt-and-catch-fire' }

    before do
      request.headers['X-Human-UUID'] = uuid
    end

    context 'when the human does not yet exist' do
      it 'creates the human and echoes back their nickname' do
        expect { get :show, format: :json }.to change {
                                                 Human.count
                                               }.from(0).to(1)

        expect(response).to be_ok
        expect(json_dig(response, 'data', 'nickname')).to be_present
        expect(json_dig(response, 'data', 'games')).to eq([])
      end
    end

    context 'when the human already exists and has some games' do
      let(:game) { create_game }
      let(:human) { Human.recognize(uuid) }
      let(:other_human) { create_human }

      before do
        GameAction::BuyIn.new(human, game).record
        GameAction::BuyIn.new(other_human, game).record
      end

      it 'shows their games' do
        expect { get :show, format: :json }.to_not(change { Human.count })

        expect(response).to be_ok
        expect(json_dig(response, 'data', 'nickname')).to eq(human.nickname)
        expect(json_dig(response, 'data', 'games'))
          .to eq([
                   {
                     'id' => game.identifier,
                     'last_action_at' => Millis.new(game.last_action_at).to_i,
                     'players' => [{
                       'id' => human.id,
                       'chips_count' => 100
                     }, {
                       'id' => other_human.id,
                       'chips_count' => 100
                     }],
                     'spectators_count' => 2,
                     'status' => 'pending',
                     'total_chips_count' => 200
                   }
                 ])
      end
    end
  end
end
