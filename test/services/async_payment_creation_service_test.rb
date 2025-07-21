require "test_helper"

class AsyncPaymentCreationServiceTest < ActiveJob::TestCase
  setup do
    @correlation_id = SecureRandom.uuid
    @amount = 100.0
    @params = {
      "correlationId" => @correlation_id,
      "amount" => @amount
    }
    @request_format = Mime::Type.lookup("application/json")
  end

  test "queues job for valid payment parameters" do
    service = AsyncPaymentCreationService.new(params: @params, request_format: @request_format)

    assert_enqueued_with(job: PaymentCreationJob) do
      result = service.call

      assert result.success?
      assert result.accepted?
      assert_equal @correlation_id, result.correlation_id
      assert result.job_id.present?
    end
  end

  test "returns validation errors for invalid parameters" do
    invalid_params = {
      "correlationId" => "invalid-uuid",
      "amount" => @amount
    }

    service = AsyncPaymentCreationService.new(params: invalid_params, request_format: @request_format)
    result = service.call

    refute result.success?
    refute result.accepted?
    assert result.errors.include?("Correlation ID must be a valid UUID")
  end

  test "returns validation errors for missing amount" do
    params_without_amount = {
      "correlationId" => @correlation_id
    }

    service = AsyncPaymentCreationService.new(params: params_without_amount, request_format: @request_format)
    result = service.call

    refute result.success?
    assert result.errors.include?("Amount is required")
  end

  test "returns validation errors for invalid amount" do
    params_with_invalid_amount = {
      "correlationId" => @correlation_id,
      "amount" => 0
    }

    service = AsyncPaymentCreationService.new(params: params_with_invalid_amount, request_format: @request_format)
    result = service.call

    refute result.success?
    assert result.errors.include?("Amount must be greater than 0")
  end

  test "queues job even for duplicate correlation ID - idempotency handled by job" do
    # Create existing payment
    Payment.create!(
      correlation_id: @correlation_id,
      amount_in_cents: 10000,
      status: :completed
    )

    service = AsyncPaymentCreationService.new(params: @params, request_format: @request_format)

    # Service should still queue a job - let the job handle idempotency
    assert_enqueued_with(job: PaymentCreationJob) do
      result = service.call

      assert result.success?
      assert result.accepted?
      assert_equal @correlation_id, result.correlation_id
      assert result.job_id.present?
    end
  end

  test "handles HTML form parameters" do
    html_params = {
      payment: {
        correlation_id: @correlation_id,
        amount: @amount
      }
    }
    html_format = Mime::Type.lookup("text/html")

    service = AsyncPaymentCreationService.new(params: html_params, request_format: html_format)

    assert_enqueued_with(job: PaymentCreationJob) do
      result = service.call
      assert result.success?
    end
  end
end
