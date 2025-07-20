class PaymentCreationService
  Result = Struct.new(:payment, :newly_created, :errors, :existing_payment_found, keyword_init: true) do
    def success?
      errors.blank?
    end

    def idempotent?
      existing_payment_found == true
    end
  end

  def initialize(params:, request_format:)
    @params = params
    @request_format = request_format
  end

  def call
    correlation_id, amount = extract_payment_params

    # Check for existing payment (idempotency)
    existing_payment = find_existing_payment(correlation_id)
    if existing_payment
      return Result.new(
        payment: existing_payment,
        newly_created: false,
        errors: [],
        existing_payment_found: true
      )
    end

    # Create new payment
    payment = build_payment(correlation_id, amount)

    if payment.save
      # Register with external service for new payments
      register_with_payment_service(payment)

      Result.new(
        payment: payment,
        newly_created: true,
        errors: [],
        existing_payment_found: false
      )
    else
      Result.new(
        payment: payment,
        newly_created: false,
        errors: payment.errors.full_messages,
        existing_payment_found: false
      )
    end
  end

  private

  attr_reader :params, :request_format

  def extract_payment_params
    if json_request?
      [ params["correlationId"], params["amount"] ]
    else
      payment_params = params[:payment] || {}
      [ payment_params[:correlation_id], payment_params[:amount] ]
    end
  end

  def find_existing_payment(correlation_id)
    return nil unless correlation_id.present?
    Payment.find_by(correlation_id: correlation_id)
  end

  def build_payment(correlation_id, amount)
    payment = Payment.new
    payment.correlation_id = correlation_id
    payment.amount = amount if amount.present?
    payment
  end

  def register_with_payment_service(payment)
    return unless payment.persisted?

    client = PaymentServiceClient.new
    service_result = client.register_payment_with_service_info(
      correlation_id: payment.correlation_id,
      amount: payment.amount,
      requested_at: payment.created_at.iso8601(3)
    )

    # Update payment with the service that was used
    payment.update!(payment_service: service_result[:service_used])

    Rails.logger.info "Payment #{payment.id} successfully registered with external service (#{service_result[:service_used]})"

  rescue PaymentServices::PaymentServiceError => e
    Rails.logger.error "Failed to register payment #{payment.id} with external service: #{e.message}"

    # Log the error but don't fail the payment creation
    # Could also implement retry logic or queue a background job here
    nil
  end

  def json_request?
    request_format&.json?
  end
end
