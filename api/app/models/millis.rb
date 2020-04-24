# frozen_string_literal: true

# Our API renders timestamps as Posix times in milliseconds.
class Millis
  def initialize(time)
    @time = time
  end

  # Convert to a milliseconds integer with as much precision as we can
  def to_i
    (time.to_f * 1_000).to_i
  end

  private

  attr_reader :time
end
