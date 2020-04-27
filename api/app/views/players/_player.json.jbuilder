# frozen_string_literal: true

# deliberately _not_ sending uuid, which is strictly for authentication
json.id player.id
json.nickname player.nickname
json.chips_count dealer.chip_count_for(player)

card = dealer.current_card_for(player)

json.current_card(if card.present? && player != current_human
                    {
                      rank: card.rank,
                      suit: card.suit
                    }
                  end)

json.in_current_hand dealer.in_current_hand?(player)
