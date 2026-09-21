require "sidekiq/api"

class HealthController < ApplicationController
  def show
    checks = {
      rails: { status: "ok", version: Rails.version },
      postgresql: database_check,
      redis: redis_check,
      sidekiq: sidekiq_check
    }
    overall = checks.values.all? { |check| check[:status] == "ok" } ? "ok" : "degraded"
    render json: { status: overall, checks: checks, timestamp: Time.current.iso8601 },
           status: overall == "ok" ? :ok : :service_unavailable
  end

  private

  def database_check
    ActiveRecord::Base.connection.execute("SELECT 1")
    { status: "ok" }
  rescue StandardError => error
    { status: "unavailable", error: error.class.name }
  end

  def redis_check
    Redis.new(url: ENV.fetch("REDIS_URL", "redis://redis:6379/0"), connect_timeout: 1).ping
    { status: "ok" }
  rescue StandardError => error
    { status: "unavailable", error: error.class.name }
  end

  def sidekiq_check
    count = Sidekiq::ProcessSet.new.size
    count.positive? ? { status: "ok", processes: count } : { status: "unavailable", processes: 0 }
  rescue StandardError => error
    { status: "unavailable", error: error.class.name }
  end
end
