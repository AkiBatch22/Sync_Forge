module Transformers
  class BaseTransformer
    COUNTRY_CODES = {
      "Australia" => "AU", "Brazil" => "BR", "Canada" => "CA", "France" => "FR",
      "Germany" => "DE", "India" => "IN", "Japan" => "JP", "United Kingdom" => "GB",
      "United States" => "US"
    }.freeze

    private

    def country_code(country)
      COUNTRY_CODES[country] || raise(IntegrationErrors::DataValidationError, "Unknown country: #{country}")
    end

    def fetch!(key)
      value = @source[key.to_s] || @source[key.to_sym]
      raise IntegrationErrors::DataValidationError, "Missing #{key}" if value.blank?

      value
    end
  end
end
