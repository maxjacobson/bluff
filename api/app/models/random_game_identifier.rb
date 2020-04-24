# frozen_string_literal: true

# Generates a fun random game id
class RandomGameIdentifier
  SUBJECTS = [
    -> { Faker::Food.fruits },
    -> { Faker::Food.ingredient },
    -> { Faker::Food.spice },
    -> { Faker::Food.sushi },
    -> { Faker::Food.vegetables },
    -> { Faker::Dessert.variety },
    -> { Faker::Dessert.topping }
  ].freeze

  ADJECTIVES = [
    -> { Faker::Color.color_name },
    -> { Faker::Vehicle.manufacture },
    -> { Faker::Science.element }
  ].freeze

  def to_s
    adjective = ADJECTIVES.sample.call
    subject = SUBJECTS.sample.call
    [adjective, subject].join(' ').parameterize
  end
end
