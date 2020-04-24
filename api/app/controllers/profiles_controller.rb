# frozen_string_literal: true

# Let the human look in the mirror
class ProfilesController < ApplicationController
  def show
    authorize! { current_human.present? }
  end
end
