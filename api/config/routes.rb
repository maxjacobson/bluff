# frozen_string_literal: true

Rails.application.routes.draw do
  resources :games, only: %i[show]
  resource :available_game_id, only: %i[show], path: 'available-game-id'
end
