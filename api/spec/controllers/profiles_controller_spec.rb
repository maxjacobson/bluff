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
        game.dealer.buy_in!(human)
        game.dealer.buy_in!(other_human)
      end

      it 'shows their games' do
        expect { get :show, format: :json }.to_not(change { Human.count })

        expect(response).to be_ok
        expect(json_dig(response, 'data', 'nickname')).to eq(human.nickname)
        expect(json_dig(response, 'data', 'games'))
          .to match(
            [
              {
                'id' => game.identifier,
                'actions' => [
                  {
                    'created_at' => anything,
                    'summary' => /joined with 100 chips/
                  },
                  {
                    'created_at' => anything,
                    'summary' => /joined with 100 chips/
                  }
                ],
                'last_action_at' => Millis.new(game.last_action_at).to_i,
                'current_dealer_id' => nil,
                'players' => [{
                  'id' => human.id,
                  'chips_count' => 100,
                  'nickname' => human.nickname,
                  'current_card' => nil
                }, {
                  'id' => other_human.id,
                  'chips_count' => 100,
                  'nickname' => other_human.nickname,
                  'current_card' => nil
                }],
                'spectators_count' => 2,
                'status' => 'pending'
              }
            ]
          )
      end
    end
  end
end
