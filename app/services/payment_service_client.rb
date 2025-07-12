require_relative "payment_services/payment_service_error"
require_relative "payment_services/base_payment_service"
require_relative "payment_services/default_payment_service"
require_relative "payment_services/fallback_payment_service"
require_relative "payment_services/payment_service_router"

# Keep the original class for backward compatibility
class PaymentServiceClient < PaymentServices::PaymentServiceRouter
  def initialize(base_url: nil, timeout: 30)
    if base_url
      # If base_url is provided, use it for both services for backward compatibility
      default_service = PaymentServices::BasePaymentService.new(base_url: base_url, timeout: timeout)
      fallback_service = PaymentServices::BasePaymentService.new(base_url: base_url, timeout: timeout)
      super(default_service: default_service, fallback_service: fallback_service)
    else
      super()
    end
  end
end
