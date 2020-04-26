# frozen_string_literal: true

json.created_at Millis.new(action.created_at).to_i
json.summary dealer.summarize_for(action, current_human)
