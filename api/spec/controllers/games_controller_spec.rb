# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GamesController do
  render_views

  describe '#show' do
    it 'creates a game if it does not exist' do
      get :show, params: { id: 'my-great-game' }, format: :json

      expect(response).to be_ok
      game = JSON.parse(response.body)
      expect(game.fetch('id')).to eq('my-great-game')
    end
  end
end
