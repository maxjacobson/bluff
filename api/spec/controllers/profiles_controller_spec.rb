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
      end
    end

    context 'when the human already exists and has some games' do
      let(:game) { create_game }
      let(:human) { Human.recognize(uuid) }
      let(:other_human) { create_human }

      before do
        game.action_creator.buy_in!(human)
        game.action_creator.buy_in!(other_human)
      end

      it 'shows their games' do
        expect { get :show, format: :json }.to_not(change { Human.count })

        expect(response).to be_ok
        expect(json_dig(response, 'data', 'nickname')).to eq(human.nickname)
      end
    end
  end
end
