class ApplicationController < ActionController::API
  before_action { Current.correlation_id = request.env.fetch("syncforge.correlation_id") }

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "not found" }, status: :not_found
  end
end
