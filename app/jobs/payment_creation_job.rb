class PaymentCreationJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 1.second, attempts: 3

  def perform(correlation_id:, amount:, request_metadata: {})
    Rails.logger.info "Processing payment creation for correlation_id: #{correlation_id}"

    # Check for existing payment (idempotency)
    existing_payment = Payment.find_by(correlation_id: correlation_id)
    if existing_payment
      Rails.logger.info "Payment already exists for correlation_id: #{correlation_id}"
      publish_payment_created_event(existing_payment)
      return existing_payment
    end

    # Create new payment with pending status
    payment = Payment.new(correlation_id: correlation_id, status: :pending)
    payment.amount = amount if amount.present?

    if payment.save
      Rails.logger.info "Payment created successfully: #{payment.id}"
      publish_payment_created_event(payment)
      payment
    else
      Rails.logger.error "Failed to create payment: #{payment.errors.full_messages}"
      raise "Payment creation failed: #{payment.errors.full_messages.join(', ')}"
    end
  end

  private

  def publish_payment_created_event(payment)
    PaymentRegistrationJob.perform_later(
      payment_id: payment.id,
      correlation_id: payment.correlation_id
    )
  end
end
