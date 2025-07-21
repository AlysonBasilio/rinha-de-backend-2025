class PaymentRegistrationJob < ApplicationJob
  queue_as :default

  retry_on PaymentServices::PaymentServiceError, wait: 2.seconds, attempts: 5
  retry_on StandardError, wait: 1.second, attempts: 3

  def perform(payment_id:, correlation_id:)
    payment = Payment.find(payment_id)

    Rails.logger.info "Processing payment registration for payment_id: #{payment_id}, status: #{payment.status}"

    # Skip registration based on payment status
    unless should_register_payment?(payment)
      Rails.logger.info "Skipping registration for payment #{payment_id} (status: #{payment.status})"
      return
    end

    # Set status to processing
    payment.update!(status: :processing)

    register_with_payment_service(payment)
  end

  private

  def should_register_payment?(payment)
    # Only register payments that are pending (newly created or waiting for retry)
    # Skip completed, failed, or processing payments
    payment.pending?
  end

  def register_with_payment_service(payment)
    client = PaymentServiceClient.new
    service_result = client.register_payment_with_service_info(
      correlation_id: payment.correlation_id,
      amount: payment.amount,
      requested_at: payment.created_at.iso8601(3)
    )

    # Update payment with the service that was used and mark as completed
    payment.update!(
      payment_service: service_result[:service_used],
      status: :completed
    )

    Rails.logger.info "Payment #{payment.id} successfully registered with external service (#{service_result[:service_used]})"

  rescue PaymentServices::PaymentServiceError => e
    Rails.logger.error "Failed to register payment #{payment.id} with external service: #{e.message}"

    # Mark as failed if this is the last retry, otherwise reset to pending for retry
    if executions >= self.class.retry_attempts
      payment.update!(status: :failed)
      Rails.logger.error "Payment #{payment.id} registration permanently failed after #{executions} attempts"
    else
      payment.update!(status: :pending)
      Rails.logger.warn "Payment #{payment.id} registration failed, will retry (attempt #{executions})"
    end

    raise e  # Let the job retry system handle this
  rescue StandardError => e
    Rails.logger.error "Unexpected error registering payment #{payment.id}: #{e.message}"
    payment.update!(status: :failed)
    raise e
  end
end
