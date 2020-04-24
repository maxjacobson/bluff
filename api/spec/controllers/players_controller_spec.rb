# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayersController do
  render_views

  describe '#show' do
    let(:game) { create_game }
    let(:uuid) { 'zoeys-extraordinary-playlist' }

    before do
      request.headers['X-Human-UUID'] = uuid
    end

    context 'when the human is not yet a player' do
      it 'converts them to a player' do
        post :create, format: :json, params: { game_id: game.identifier }

        expect(response).to be_created
        json = JSON.parse(response.body)
        expect(json.fetch('data').fetch('id')).to eq(game.identifier)
        expect(json.fetch('meta').fetch('human').fetch('role')).to eq('player')
      end
    end

    context 'when the human is already a player' do
      it 'no-ops' do
        2.times do
          post :create, format: :json, params: { game_id: game.identifier }
        end

        expect(response).to be_created
        json = JSON.parse(response.body)
        expect(json.fetch('data').fetch('id')).to eq(game.identifier)
        expect(json.fetch('meta').fetch('human').fetch('role')).to eq('player')
      end
    end
  end
end
