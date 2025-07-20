require_relative "payment_service_error"
require_relative "default_payment_service"
require_relative "fallback_payment_service"

module PaymentServices
  class PaymentServiceRouter
    def initialize(default_service: nil, fallback_service: nil)
      @default_service = default_service || DefaultPaymentService.new
      @fallback_service = fallback_service || FallbackPaymentService.new
    end

    def register_payment_with_service_info(correlation_id:, amount:, requested_at: nil)
      Rails.logger.info "Attempting payment registration with default service"

      begin
        result = @default_service.register_payment(
          correlation_id: correlation_id,
          amount: amount,
          requested_at: requested_at
        )
        { result: result, service_used: "default" }
      rescue PaymentServiceError => e
        if service_unavailable?(e)
          Rails.logger.warn "Default payment service unavailable, falling back to fallback service"
          Rails.logger.debug "Default service error: #{e.message}"

          result = @fallback_service.register_payment(
            correlation_id: correlation_id,
            amount: amount,
            requested_at: requested_at
          )
          { result: result, service_used: "fallback" }
        else
          # Re-raise the error if it's not a service availability issue
          raise e
        end
      end
    end

    private

    def service_unavailable?(error)
      # Consider service unavailable if it's a timeout, connection error, or 5xx server error
      error.status_code == :timeout ||
        error.message.include?("connection error") ||
        (error.status_code.is_a?(Integer) && error.status_code >= 500)
    end
  end
end
