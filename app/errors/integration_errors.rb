module IntegrationErrors
  class Error < StandardError; end
  class RecoverableError < Error; end
  class ExternalApiTimeout < RecoverableError; end
  class RateLimitError < RecoverableError
    attr_reader :retry_after

    def initialize(message = "ERP rate limit reached", retry_after: 60)
      @retry_after = retry_after
      super(message)
    end
  end
  class TemporaryServiceUnavailable < RecoverableError; end

  class InvalidPayloadError < Error; end
  class AuthenticationError < Error; end
  class UnsupportedEntityError < Error; end
  class DataValidationError < Error; end
end
