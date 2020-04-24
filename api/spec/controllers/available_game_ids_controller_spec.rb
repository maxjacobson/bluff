# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AvailableGameIdsController do
  render_views

  describe '#show' do
    let(:uuid) { 'zoeys-extraordinary-playlist' }

    before do
      request.headers['X-Human-UUID'] = uuid
    end

    context 'when the game does not yet exist' do
      it 'creates the game' do
        get :show, format: :json

        expect(response).to be_ok
        json = JSON.parse(response.body)
        expect(json.fetch('data').fetch('id')).to be_present
      end
    end
  end
end
