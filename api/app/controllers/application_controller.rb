# frozen_string_literal: true

# Base class for all controllers. Houses any global logic.
class ApplicationController < ActionController::API
  before_action :recognize_human
  after_action :verify_authorization_was_checked

  # This should hopefully never get raised in production. This is meant to
  # help ensure we never forget to think about whether a request is allowed.
  AuthorizationNotChecked = Class.new(StandardError)
  NotAuthorized = Class.new(StandardError)

  rescue_from NotAuthorized, with: :unauthorized

  private

  attr_accessor :current_human
  helper_method :current_human

  def authorize!(&block)
    raise NotAuthorized unless block.call

    @authorized = true
  end

  def recognize_human
    uuid = request.headers['X-Human-UUID']
    self.current_human = Human.recognize(uuid)
  end

  def verify_authorization_was_checked
    raise AuthorizationNotChecked unless @authorized
  end

  def unauthorized(_exception)
    render json: {}, status: :unauthorized
  end
end
