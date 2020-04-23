# frozen_string_literal: true

# Endpoints to load info about a game of bluff
class GamesController < ApplicationController
  def show
    @game = Game.create_or_find_by(identifier: params[:id])
  end
end