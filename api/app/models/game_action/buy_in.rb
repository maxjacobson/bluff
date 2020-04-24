# frozen_string_literal: true

class GameAction
  # Records a GameAction of action = 'buy_in'. That action represents a player
  # joining the game and getting their initial stack of chips. There's no
  # actual money involved, this is just for fun.
  class BuyIn
    # The number of chips each player will start with. This is completely
    # arbitrary.
    DEFAULT_AMOUNT = 100

    def initialize(human, game)
      @attendance = game.attendances.create_or_find_by!(human_id: human.id)

      @dealer = game.dealer
    end

    def record
      return unless dealer.can_join?(attendance.human)

      GameAction.create!(
        attendance: attendance,
        action: 'buy_in',
        value: DEFAULT_AMOUNT
      )
    end

    private

    attr_reader :attendance, :dealer
  end
end
