# frozen_string_literal: true

# deliberately _not_ sending uuid, which is strictly for authentication
json.id player.id
json.nickname player.nickname
json.chips_count dealer.chip_count_for(player)
