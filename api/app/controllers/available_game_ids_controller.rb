# frozen_string_literal: true

# Populates the suggested game id on the homepage
class AvailableGameIdsController < ApplicationController
  def show
    # Anyone can ask for an available game id
    authorize! { current_human.present? }

    @id = Game.available_identifier
  end
end
