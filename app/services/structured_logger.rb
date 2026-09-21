class StructuredLogger
  def self.log(level:, event:, message:, **context)
    payload = {
      timestamp: Time.current.iso8601(3), level: level, correlation_id: Current.correlation_id,
      service: "syncforge", event: event, message: message
    }.merge(context).compact
    Rails.logger.public_send(level, payload.to_json)
  end
end
