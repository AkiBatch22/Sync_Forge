class CorrelationIdMiddleware
  HEADER = "HTTP_X_CORRELATION_ID".freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    correlation_id = valid_uuid(env[HEADER]) || SecureRandom.uuid
    env["syncforge.correlation_id"] = correlation_id
    status, headers, body = @app.call(env)
    headers["X-Correlation-ID"] = correlation_id
    [ status, headers, body ]
  end

  private

  def valid_uuid(value)
    value if value.to_s.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
  end
end
