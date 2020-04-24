# frozen_string_literal: true

module JSONExpectationHelper
  def json_dig(response, *keys)
    json = JSON.parse(response.body)
    keys.inject(json) do |obj, key|
      obj.fetch(key)
    rescue KeyError
      raise KeyError, "key not found #{key.inspect} in #{obj.inspect}"
    end
  end
end

RSpec.configure do |config|
  config.include(JSONExpectationHelper)
end
