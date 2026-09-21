module Transformers
  class CustomerTransformer < BaseTransformer
    STATUS_MAP = { "active" => "ACTIVE", "inactive" => "INACTIVE", "prospect" => "PROSPECT" }.freeze

    def initialize(source)
      @record = source if source.respond_to?(:attributes)
      @source = source.respond_to?(:attributes) ? source.attributes : source.to_h
    end

    def call
      email = fetch!(:email)
      raise IntegrationErrors::DataValidationError, "Invalid email" unless URI::MailTo::EMAIL_REGEXP.match?(email)

      {
        external_id: fetch!(:external_id),
        full_name: [ fetch!(:first_name), fetch!(:last_name) ].join(" "),
        email_address: email,
        phone_number: @source["phone"] || @source[:phone],
        country_code: country_code(fetch!(:country)),
        customer_status: STATUS_MAP.fetch(fetch!(:status).downcase) do
          raise IntegrationErrors::DataValidationError, "Unknown customer status"
        end,
        company_external_id: company_external_id
      }
    end

    private

    def company_external_id
      return @record.company&.external_id if @record

      @source["company_external_id"] || @source[:company_external_id]
    end
  end
end
