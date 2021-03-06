# frozen_string_literal: true

Rails.application.routes.draw do
  resource :profile, only: %i[show update]

  resources :games, only: %i[show] do
    resources :players, only: %i[create]
    resource :start, only: %i[create], controller: 'game_starts'
    resources :bets, only: %i[create]
    resources :checks, only: %i[create]
    resources :folds, only: %i[create]
  end

  resource :available_game_id, only: %i[show], path: 'available-game-id'
end
