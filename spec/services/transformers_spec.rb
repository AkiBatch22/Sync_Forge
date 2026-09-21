require "rails_helper"

RSpec.describe "CRM to ERP transformers" do
  describe Transformers::CustomerTransformer do
    it "renames, combines, and maps customer fields" do
      customer = build(:customer)
      result = described_class.new(customer).call
      expect(result).to include(full_name: "Akshat Bajaj", email_address: customer.email,
                                country_code: "IN", customer_status: "ACTIVE")
    end

    it "includes the source company external ID" do
      customer = build(:customer)
      expect(described_class.new(customer).call[:company_external_id]).to eq(customer.company.external_id)
    end

    it "rejects a missing email" do
      expect { described_class.new(build(:customer, email: nil)).call }
        .to raise_error(IntegrationErrors::DataValidationError, /Missing email/)
    end

    it "rejects an unknown country" do
      expect { described_class.new(build(:customer, country: "Unknownland")).call }
        .to raise_error(IntegrationErrors::DataValidationError, /Unknown country/)
    end
  end

  describe Transformers::CompanyTransformer do
    it "maps company fields" do
      result = described_class.new(build(:company)).call
      expect(result).to include(company_name: "Acme Synthetic Ltd", employee_total: 100, country_code: "IN")
    end

    it "preserves revenue" do
      expect(described_class.new(build(:company)).call[:annual_revenue]).to eq(1_000_000)
    end

    it "requires a company name" do
      expect { described_class.new(build(:company, name: nil)).call }
        .to raise_error(IntegrationErrors::DataValidationError, /Missing name/)
    end
  end
end
