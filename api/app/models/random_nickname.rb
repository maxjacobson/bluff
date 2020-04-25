# frozen_string_literal: true

# Helps generate a fun random default nickname for humans.
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
