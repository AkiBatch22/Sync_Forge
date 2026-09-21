class DestinationRateLimiter
  LIMIT = 100
  WINDOW = 60

  def initialize(redis: Redis.new(url: ENV.fetch("REDIS_URL", "redis://redis:6379/0")))
    @redis = redis
  end

  def check!(destination)
    window = Time.current.to_i / WINDOW
    key = "syncforge:rate_limit:#{destination}:#{window}"
    count = @redis.incr(key)
    @redis.expire(key, WINDOW + 5) if count == 1
    return if count <= LIMIT

    retry_after = WINDOW - (Time.current.to_i % WINDOW)
    raise IntegrationErrors::RateLimitError.new(retry_after: retry_after)
  rescue Redis::BaseError => error
    StructuredLogger.log(level: :warn, event: "rate_limiter_unavailable", message: error.message)
    true
  end
end
