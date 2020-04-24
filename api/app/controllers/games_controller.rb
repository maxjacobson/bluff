# frozen_string_literal: true

# Endpoints to load info about a game of bluff
class GamesController < ApplicationController
  def show
    # Anyone can view a game
    authorize! { current_human.present? }

    @game = Game.create_or_find_by(identifier: params[:id])

    current_human.record_heartbeat(@game)
  end
end
