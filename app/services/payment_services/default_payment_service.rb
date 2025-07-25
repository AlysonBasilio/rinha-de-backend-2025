require_relative "base_payment_service"

module PaymentServices
  class DefaultPaymentService < BasePaymentService
    def initialize(timeout: 30)
      base_url = ENV["DEFAULT_PAYMENT_SERVICE_URL"] || "http://localhost:8001"
      super(base_url: base_url, timeout: timeout)
    end
  end
end
