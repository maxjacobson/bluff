# frozen_string_literal: true

# Helps generate a fun random nickname for humans. Maybe later we'll let them
# override this.
class RandomNickname
  def to_s
    [fun_word, animal].join(' ').titlecase
  end

  private

  def fun_word
    @fun_word ||= Faker::Hipster.word
  end

  def animal
    @animal ||= Faker::Creature::Animal.name
  end
end
