module ErpFailureSimulation
  extend ActiveSupport::Concern

  included { before_action :simulate_failure }

  private

  def simulate_failure
    mode = allowed_failure_mode
    case mode
    when "none" then nil
    when "timeout" then sleep(6)
    when "rate_limit" then render json: { error: "synthetic rate limit" }, status: :too_many_requests,
                                  headers: { "Retry-After" => "5" }
    when "server_error" then render json: { error: "synthetic server error" }, status: :internal_server_error
    when "unauthorized" then render json: { error: "synthetic unauthorized" }, status: :unauthorized
    when "invalid_request" then render json: { error: "synthetic invalid request" }, status: :bad_request
    end
  end

  def allowed_failure_mode
    configured = ENV.fetch("ERP_FAILURE_MODE", "none")
    return configured unless Rails.env.development? || Rails.env.test?

    request.headers["X-Failure-Mode"].presence || configured
  end
end
