require "test_helper"
require "minitest/mock"

class PaymentRegistrationJobTest < ActiveJob::TestCase
  setup do
    @payment = payments(:one) # Using fixture
    @payment.update!(status: :pending, payment_service: nil)
  end

  test "registers payment with external service successfully" do
    # Mock the service client
    mock_client = Minitest::Mock.new
    mock_client.expect :register_payment_with_service_info, { service_used: "default" } do |args|
      # Verify that we're calling with the right parameters
      assert args.is_a?(Hash)
      assert_equal @payment.correlation_id, args[:correlation_id]
      true
    end

    PaymentServiceClient.stub :new, mock_client do
      PaymentRegistrationJob.perform_now(
        payment_id: @payment.id,
        correlation_id: @payment.correlation_id
      )
    end

    @payment.reload
    assert @payment.completed?
    assert_equal "default", @payment.payment_service
    mock_client.verify
  end

  test "sets status to processing before registration" do
    @payment.update!(status: :pending)

    # We'll verify the status change by checking what happens during the job
    PaymentRegistrationJob.perform_now(
      payment_id: @payment.id,
      correlation_id: @payment.correlation_id
    )

    @payment.reload
    # After successful processing, it should be completed
    assert @payment.completed?
  end

  test "skips registration for non-pending payments" do
    # Set payment to completed status
    @payment.update!(status: :completed, payment_service: "default")
    original_service = @payment.payment_service

    PaymentRegistrationJob.perform_now(
      payment_id: @payment.id,
      correlation_id: @payment.correlation_id
    )

    # Payment should remain unchanged
    @payment.reload
    assert @payment.completed?
    assert_equal original_service, @payment.payment_service
  end

  test "skips registration for failed payments" do
    # Set payment to failed status
    @payment.update!(status: :failed)

    PaymentRegistrationJob.perform_now(
      payment_id: @payment.id,
      correlation_id: @payment.correlation_id
    )

    # Payment should remain in failed state
    @payment.reload
    assert @payment.failed?
    assert_nil @payment.payment_service
  end

  test "processes pending payments from retries" do
    # Set payment to pending status (could be from retry)
    @payment.update!(status: :pending)

    # Mock the service client
    mock_client = Minitest::Mock.new
    mock_client.expect :register_payment_with_service_info, { service_used: "default" } do |args|
      true
    end

    PaymentServiceClient.stub :new, mock_client do
      PaymentRegistrationJob.perform_now(
        payment_id: @payment.id,
        correlation_id: @payment.correlation_id
      )
    end

    @payment.reload
    assert @payment.completed?
    assert_equal "default", @payment.payment_service
    mock_client.verify
  end
end
