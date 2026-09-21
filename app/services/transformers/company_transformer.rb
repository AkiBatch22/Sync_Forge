module Transformers
  class CompanyTransformer < BaseTransformer
    def initialize(source)
      @source = source.respond_to?(:attributes) ? source.attributes : source.to_h
    end

    def call
      {
        external_id: fetch!(:external_id),
        company_name: fetch!(:name),
        industry: @source["industry"] || @source[:industry],
        employee_total: @source["employee_count"] || @source[:employee_count],
        country_code: country_code(fetch!(:country)),
        annual_revenue: @source["annual_revenue"] || @source[:annual_revenue]
      }
    end
  end
end
