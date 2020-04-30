# frozen_string_literal: true

# Let's players pass their turn rather than bet
class ChecksController < ApplicationController
  def create
    authorize! { current_human.present? }

    @game = Game.find_by!(identifier: params.require(:game_id))
    @game.action_creator.check!(current_human)

    render status: :created
  end
end
