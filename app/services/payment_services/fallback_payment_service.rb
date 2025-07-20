require_relative "base_payment_service"

module PaymentServices
  class FallbackPaymentService < BasePaymentService
    def initialize(timeout: 30)
      base_url = ENV["FALLBACK_PAYMENT_SERVICE_URL"] || "http://localhost:8002"
      super(base_url: base_url, timeout: timeout)
    end
  end
end
