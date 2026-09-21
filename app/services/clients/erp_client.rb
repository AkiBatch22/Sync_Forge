require "net/http"

module Clients
  class ErpClient
    def initialize(base_url: ENV.fetch("ERP_BASE_URL", "http://web:3000"), failure_mode: nil)
      @base_uri = URI(base_url)
      @failure_mode = failure_mode
    end

    def upsert(entity_type:, external_id:, payload:, event_type:, correlation_id:)
      created = event_type.end_with?(".created")
      path = "/erp/v1/#{entity_type}s"
      path += "/#{CGI.escape(external_id)}" unless created
      request = created ? Net::HTTP::Post.new(path) : Net::HTTP::Put.new(path)
      request["Content-Type"] = "application/json"
      request["X-Correlation-ID"] = correlation_id
      request["X-Failure-Mode"] = @failure_mode if @failure_mode
      request.body = payload.to_json
      response = perform(request)
      handle_response!(response)
      JSON.parse(response.body)
    rescue Net::OpenTimeout, Net::ReadTimeout => error
      raise IntegrationErrors::ExternalApiTimeout, error.message
    rescue Errno::ECONNREFUSED, SocketError => error
      raise IntegrationErrors::TemporaryServiceUnavailable, error.message
    end

    private

    def perform(request)
      Net::HTTP.start(@base_uri.host, @base_uri.port, use_ssl: @base_uri.scheme == "https",
                      open_timeout: 2, read_timeout: 5) { |http| http.request(request) }
    end

    def handle_response!(response)
      case response.code.to_i
      when 200..299 then true
      when 400 then raise IntegrationErrors::InvalidPayloadError, response.body
      when 401, 403 then raise IntegrationErrors::AuthenticationError, response.body
      when 429
        raise IntegrationErrors::RateLimitError.new(response.body, retry_after: response["Retry-After"].to_i.nonzero? || 60)
      when 500..599 then raise IntegrationErrors::TemporaryServiceUnavailable, response.body
      else raise IntegrationErrors::InvalidPayloadError, "Unexpected ERP response #{response.code}"
      end
    end
  end
end
