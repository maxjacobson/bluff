# frozen_string_literal: true

# Base class for ActiveRecord models, will house some common helpers (if any)
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
