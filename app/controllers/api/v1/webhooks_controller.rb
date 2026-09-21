module Api
  module V1
    class WebhooksController < ApplicationController
      def create
        raw_body = request.raw_post
        return render json: { error: "invalid signature" }, status: :unauthorized unless valid_signature?(raw_body)

        body = JSON.parse(raw_body)
        result = WebhookIngestor.new(attributes(body)).call
        status = result.duplicate ? :ok : :accepted
        render json: { id: result.webhook_event.id, status: result.webhook_event.status,
                       duplicate: result.duplicate, correlation_id: result.webhook_event.correlation_id }, status: status
      rescue JSON::ParserError
        render json: { error: "invalid JSON" }, status: :bad_request
      rescue KeyError, ActiveRecord::RecordInvalid => error
        render json: { error: error.message }, status: :unprocessable_content
      end

      private

      def attributes(body)
        event_type = body.fetch("event_type")
        entity_type = body.fetch("entity_type")
        unless WebhookEvent::SUPPORTED_EVENTS.include?(event_type) && event_type.start_with?("#{entity_type}.")
          raise KeyError, "unsupported event/entity combination"
        end

        {
          external_event_id: body.fetch("external_event_id"), event_type: event_type,
          entity_type: entity_type, entity_external_id: body.fetch("entity_external_id"),
          payload: body.fetch("payload"), status: "received",
          correlation_id: Current.correlation_id, received_at: Time.current
        }
      end

      def valid_signature?(body)
        supplied = request.headers["X-SyncForge-Signature"].to_s.delete_prefix("sha256=")
        expected = OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, body)
        supplied.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(supplied, expected)
      end

      def webhook_secret
        ENV.fetch("CRM_WEBHOOK_SECRET") { Rails.env.production? ? raise(KeyError, "CRM_WEBHOOK_SECRET is required") : "development-secret" }
      end
    end
  end
end
