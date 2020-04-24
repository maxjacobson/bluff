# frozen_string_literal: true

json.data do
  json.id @id
end

json.meta do
  if current_human.present?
    json.human do
      json.nickname current_human.nickname
    end
  end
end
