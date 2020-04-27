# frozen_string_literal: true

class BetsController < ApplicationController
  def create
    authorize! { current_human.present? }

    @game = Game.find_by!(identifier: params.require(:game_id))

    @game.dealer.bet!(amount, current_human)

    render status: :created
  end

  private

  def amount
    params.require(:bets).require(:amount)
  end
end
