# frozen_string_literal: true

player = dealer.action_to

if player.present?
  attendance = game.attendance_for(player)
  # FIXME: we only include some of this info because we already had an elm type
  #        with this schema, but we could introduce a new type and omit some.
  json.player do
    json.id player.id
    json.nickname player.nickname
    json.heartbeat_at Millis.new(attendance.heartbeat_at).to_i
    json.role dealer.role(player)
  end

  # Can the action player bet? (Note: this includes raising and calling)
  json.bet do
    json.available dealer.can_bet?(player)
    json.minimum dealer.minimum_bet(player)
    json.maximum dealer.maximum_bet(player)
  end

  # Can the player check?
  json.check do
    json.available dealer.can_check?(player)
  end

  # Can the action player fold?
  json.fold do
    json.available dealer.can_fold?(player)
  end
else
  json.null!
end
