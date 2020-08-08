# frozen_string_literal: true

# By design, this system is ephemeral. To keep the system fast, we're probably
# going to want to periodically prune stale rows, particularly ones related to
# humans that never engaged and games that were never played.
namespace :prune do
  # Artificially low while I test this out, will increase later
  CUTOFF = 12.hours

  task abandoned_games: :environment do
    logger = Logger.new($stdout)

    Game.find_each do |game|
      if game.last_action_at > CUTOFF.ago
        logger.info "Preserving fresh game id=#{game.id}" \
                    "last_action_at=#{game.last_action_at} " \
                    "status=#{game.dealer.status}"
        next
      end

      if game.dealer.status.complete?
        logger.info "Preserving complete game id=#{game.id}"
        next
      end

      logger.info "Deleting stale game id=#{game.id} " \
                  "last_action_at=#{game.last_action_at} " \
                  "status=#{game.dealer.status}"

      # This will cascade and destroy all of the attendances and actions, too.
      game.destroy
    end
  end

  task stale_humans: :environment do
    # This would get a bit more complicated... we don't want to delete only
    # _some_ of the game actions for a game, which could hapen if we delete
    # a stale human, and that cascades to their attendances and actions.
    # We could safely destroy humans who never actually played a game, though.
    # And that would work in concert with the other prune task.

    logger = Logger.new($stdout)

    Human.find_each do |human|
      if human.created_at > CUTOFF.ago
        logger.info "Preserving fresh human id=#{human.id}"
        next
      end

      if human.games.any?
        logger.info "Preserving engaged human id=#{human.id}"
        next
      end

      logger.info "Deleting stale human id=#{human.id}"
      human.destroy
    end
  end
end
