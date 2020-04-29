# frozen_string_literal: true

module GameStatus
  PENDING = ActiveSupport::StringInquirer.new('pending').freeze
  PLAYING = ActiveSupport::StringInquirer.new('playing').freeze
  COMPLETE = ActiveSupport::StringInquirer.new('complete').freeze
end
