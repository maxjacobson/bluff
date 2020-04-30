# frozen_string_literal: true

# Lets players get out while the getting's good
class FoldsController < ApplicationController
  def create
    authorize! { current_human.present? }

    @game = Game.find_by!(identifier: params.require(:game_id))
    @game.action_creator.fold!(current_human)

    render status: :created
  end
end
