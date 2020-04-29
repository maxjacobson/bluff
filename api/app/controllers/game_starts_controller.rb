# frozen_string_literal: true

# Players can start a game once enough players have joined
class GameStartsController < ApplicationController
  def create
    authorize! { current_human.present? }

    @game = Game.find_by!(identifier: params.require(:game_id))

    @game.action_creator.start!(current_human)

    render status: :created
  end
end
