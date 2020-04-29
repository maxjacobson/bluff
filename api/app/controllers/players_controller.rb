# frozen_string_literal: true

# Allows humans to register interest in playing a game
class PlayersController < ApplicationController
  def create
    # Anyone can join a game
    authorize! { current_human.present? }

    @game = Game.find_by!(identifier: params.require(:game_id))
    @game.action_creator.buy_in!(current_human)

    render status: :created
  end
end
