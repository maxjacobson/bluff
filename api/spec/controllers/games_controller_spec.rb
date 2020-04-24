# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GamesController do
  render_views

  describe '#show' do
    let(:uuid) { 'bars-of-gold' }

    before do
      request.headers['X-Human-UUID'] = uuid
    end

    context 'when the game does not yet exist' do
      it 'creates the game' do
        get :show, params: { id: 'my-great-game' }, format: :json

        expect(response).to be_ok
        game = JSON.parse(response.body)
        expect(game.fetch('data').fetch('id')).to eq('my-great-game')
        expect(game.fetch('data').fetch('status')).to eq('pending')
      end
    end

    context 'when the game already exists' do
      it 'echoes back the game' do
        Game.create!(identifier: 'my-so-so-game')

        expect do
          get :show, params: { id: 'my-so-so-game' }, format: :json
        end.to_not(change { Game.count })

        expect(response).to be_ok
        game = JSON.parse(response.body)
        expect(game.fetch('data').fetch('id')).to eq('my-so-so-game')
      end
    end

    context 'when the human does not yet exist' do
      it 'creates the human' do
        expect do
          get :show, params: { id: 'my-great-game' }, format: :json
        end.to change { Human.count }.from(0).to(1)

        expect(response).to be_ok
        expect(Human.first.uuid).to eq(uuid)
      end
    end

    context 'when the human already exists' do
      before do
        Human.create!(uuid: uuid, nickname: 'Jane')
      end

      it 'does not create a duplicate human' do
        expect do
          get :show, params: { id: 'my-great-game' }, format: :json
        end.to_not(change { Human.count })

        expect(response).to be_ok
        expect(Human.first.uuid).to eq(uuid)
      end
    end
  end
end
