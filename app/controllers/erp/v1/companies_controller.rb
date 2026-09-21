module Erp
  module V1
    class CompaniesController < ApplicationController
      include ErpFailureSimulation

      def create
        record = ErpCompany.create!(company_params)
        render json: record, status: :created
      rescue ActiveRecord::RecordInvalid => error
        render json: { error: error.record.errors.full_messages }, status: :bad_request
      end

      def update
        record = ErpCompany.find_or_initialize_by(external_id: params[:external_id])
        record.update!(company_params)
        render json: record
      rescue ActiveRecord::RecordInvalid => error
        render json: { error: error.record.errors.full_messages }, status: :bad_request
      end

      private

      def company_params
        params.permit(:external_id, :company_name, :industry, :employee_total, :country_code, :annual_revenue)
      end
    end
  end
end
