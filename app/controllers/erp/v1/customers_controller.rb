module Erp
  module V1
    class CustomersController < ApplicationController
      include ErpFailureSimulation

      def create
        record = ErpCustomer.create!(customer_params)
        render json: record, status: :created
      rescue ActiveRecord::RecordInvalid => error
        render json: { error: error.record.errors.full_messages }, status: :bad_request
      end

      def update
        record = ErpCustomer.find_or_initialize_by(external_id: params[:external_id])
        record.update!(customer_params)
        render json: record
      rescue ActiveRecord::RecordInvalid => error
        render json: { error: error.record.errors.full_messages }, status: :bad_request
      end

      def show
        render json: ErpCustomer.find_by!(external_id: params[:external_id])
      end

      private

      def customer_params
        params.permit(:external_id, :full_name, :email_address, :phone_number,
                      :country_code, :customer_status, :company_external_id)
      end
    end
  end
end
