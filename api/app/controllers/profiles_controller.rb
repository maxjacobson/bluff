# frozen_string_literal: true

# Let the human look in the mirror
class ProfilesController < ApplicationController
  def show
    # Anyone can see their own profile
    authorize! { current_human.present? }
  end

  def update
    # Anyone can update their own profile
    authorize! { current_human.present? }

    current_human.update!(profile_params)

    render :show, status: :ok
  end

  private

  def profile_params
    params.require(:profile).permit(:nickname)
  end
end
