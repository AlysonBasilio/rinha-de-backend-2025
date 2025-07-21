require "test_helper"

class PaymentCreationJobTest < ActiveJob::TestCase
  setup do
    @correlation_id = SecureRandom.uuid
    @amount = 100.0
  end

  test "creates a new payment successfully" do
    assert_difference "Payment.count", 1 do
      PaymentCreationJob.perform_now(
        correlation_id: @correlation_id,
        amount: @amount
      )
    end

    payment = Payment.find_by(correlation_id: @correlation_id)
    assert payment.present?
    assert_equal @amount, payment.amount
    assert payment.pending?
  end

  test "queues PaymentRegistrationJob after creating payment" do
    assert_enqueued_with(job: PaymentRegistrationJob) do
      PaymentCreationJob.perform_now(
        correlation_id: @correlation_id,
        amount: @amount
      )
    end
  end

  test "handles existing payment idempotently" do
    # Create existing payment
    existing_payment = Payment.create!(
      correlation_id: @correlation_id,
      amount_in_cents: 10000,
      status: :completed
    )

    assert_no_difference "Payment.count" do
      result = PaymentCreationJob.perform_now(
        correlation_id: @correlation_id,
        amount: @amount
      )
      assert_equal existing_payment, result
    end
  end

  test "does not create payment for invalid data" do
    initial_count = Payment.count

    # Job should complete but not create a payment due to validation failure
    PaymentCreationJob.perform_now(
      correlation_id: "not-a-valid-uuid-format",
      amount: @amount
    )

    # Payment count should not increase
    assert_equal initial_count, Payment.count

    # No payment should exist with this invalid correlation ID
    assert_nil Payment.find_by(correlation_id: "not-a-valid-uuid-format")
  end

  test "queues registration job for existing payments too" do
    # Create existing payment
    Payment.create!(
      correlation_id: @correlation_id,
      amount_in_cents: 10000,
      status: :completed
    )

    assert_enqueued_with(job: PaymentRegistrationJob) do
      PaymentCreationJob.perform_now(
        correlation_id: @correlation_id,
        amount: @amount
      )
    end
  end
end
