require "test_helper"

class PaymentCreationServiceTest < ActiveSupport::TestCase
  setup do
    @correlation_id = "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b1"
    @amount = 19.90
  end

  test "creates new payment successfully with JSON params and calls external service" do
    # Stub both services to return success from default
    stub_request(:post, "http://localhost:8001/payments")
      .to_return(status: 200, body: '{"status": "success"}')

    params = {
      "correlationId" => @correlation_id,
      "amount" => @amount
    }

    double_json_format = double_json_format()
    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert result.success?
    refute result.existing_payment_found
    assert_not result.idempotent?
    assert_equal @correlation_id, result.payment.correlation_id
    assert_equal @amount, result.payment.amount
    assert_equal "default", result.payment.payment_service
    assert result.payment.persisted?

    # Verify external service was called
    assert_requested :post, "http://localhost:8001/payments"
  end

  test "creates new payment successfully with HTML params and calls external service" do
    # Stub both services to return success from default
    stub_request(:post, "http://localhost:8001/payments")
      .to_return(status: 200, body: '{"status": "success"}')

    params = {
      payment: {
        correlation_id: @correlation_id,
        amount: @amount
      }
    }

    double_html_format = double_html_format()
    service = PaymentCreationService.new(params: params, request_format: double_html_format)
    result = service.call

    assert result.success?
    refute result.existing_payment_found
    assert_not result.idempotent?
    assert_equal @correlation_id, result.payment.correlation_id
    assert_equal @amount, result.payment.amount
    assert_equal "default", result.payment.payment_service
    assert result.payment.persisted?

    # Verify external service was called
    assert_requested :post, "http://localhost:8001/payments"
  end

  test "returns existing payment for duplicate correlation id (idempotency) without calling external service" do
    # Create existing payment
    existing_payment = Payment.create!(
      correlation_id: @correlation_id,
      amount_in_cents: 1990
    )

    # Stub the external service - it should NOT be called for existing payments
    stub_request(:post, "http://localhost:8001/payments")
      .to_return(status: 200, body: '{"status": "success"}')

    params = {
      "correlationId" => @correlation_id,
      "amount" => @amount
    }

    double_json_format = double_json_format()
    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert result.success?
    assert result.existing_payment_found
    assert result.idempotent?
    assert_equal existing_payment.id, result.payment.id
    assert_equal @correlation_id, result.payment.correlation_id
    assert_equal @amount, result.payment.amount

    # Verify external service was NOT called for existing payment
    assert_not_requested :post, "http://localhost:8001/payments"
  end

  test "returns errors for invalid payment" do
    params = {
      "correlationId" => "invalid-uuid",
      "amount" => @amount
    }

    double_json_format = double_json_format()
    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    refute result.success?
    refute result.existing_payment_found
    assert_not result.idempotent?
    assert result.errors.include?("Correlation must be a valid UUID")
    refute result.payment.persisted?
  end

  test "handles missing correlation id" do
    params = {
      "amount" => @amount
    }

    double_json_format = double_json_format()
    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    refute result.success?
    refute result.existing_payment_found
    assert_not result.idempotent?
    assert result.errors.include?("Correlation can't be blank")
    refute result.payment.persisted?
  end

  test "handles missing amount" do
    params = {
      "correlationId" => @correlation_id
    }

    double_json_format = double_json_format()
    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    refute result.success?
    refute result.existing_payment_found
    assert_not result.idempotent?
    assert result.errors.include?("Amount in cents can't be blank")
    refute result.payment.persisted?
  end

  test "handles empty params gracefully" do
    params = {}

    double_json_format = double_json_format()
    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    refute result.success?
    refute result.existing_payment_found
    assert_not result.idempotent?
    assert result.errors.any?
    refute result.payment.persisted?
  end

  test "handles string amounts correctly" do
    # Stub both services to return success from default
    stub_request(:post, "http://localhost:8001/payments")
      .to_return(status: 200, body: '{"status": "success"}')

    params = {
      "correlationId" => @correlation_id,
      "amount" => "25.50"  # String amount
    }

    double_json_format = double_json_format()
    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert result.success?
    refute result.existing_payment_found
    assert_not result.idempotent?
    assert_equal @correlation_id, result.payment.correlation_id
    assert_equal 25.50, result.payment.amount
    assert_equal "default", result.payment.payment_service
    assert result.payment.persisted?
  end

  test "sets payment service to 'default' when default service is used" do
    # Stub default service to succeed
    stub_request(:post, "http://localhost:8001/payments")
      .to_return(status: 200, body: '{"status": "success"}')

    params = {
      "correlationId" => @correlation_id,
      "amount" => @amount
    }

    double_json_format = double_json_format()
    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert result.success?
    refute result.existing_payment_found
    assert_equal "default", result.payment.payment_service
  end

  test "sets payment service to 'fallback' when fallback service is used" do
    # Stub default service to fail and fallback to succeed
    stub_request(:post, "http://localhost:8001/payments")
      .to_return(status: 500, body: '{"error": "Service unavailable"}')

    stub_request(:post, "http://localhost:8002/payments")
      .to_return(status: 200, body: '{"status": "success"}')

    params = {
      "correlationId" => @correlation_id,
      "amount" => @amount
    }

    double_json_format = double_json_format()
    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert result.success?
    refute result.existing_payment_found
    assert_equal "fallback", result.payment.payment_service

    # Verify both services were called
    assert_requested :post, "http://localhost:8001/payments"
    assert_requested :post, "http://localhost:8002/payments"
  end

  test "does not set payment service for existing payments (idempotency)" do
    # Create existing payment without payment_service
    existing_payment = Payment.create!(
      correlation_id: @correlation_id,
      amount_in_cents: 1990
    )

    # Stub the external service - it should NOT be called for existing payments
    stub_request(:post, "http://localhost:8001/payments")
      .to_return(status: 200, body: '{"status": "success"}')

    params = {
      "correlationId" => @correlation_id,
      "amount" => @amount
    }

    double_json_format = double_json_format()
    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert result.success?
    assert result.existing_payment_found
    assert result.idempotent?
    assert_equal existing_payment.id, result.payment.id
    assert_nil result.payment.payment_service  # Should remain nil

    # Verify external service was NOT called
    assert_not_requested :post, "http://localhost:8001/payments"
  end

  test "payment creation succeeds even if external service registration fails" do
    # Stub both services to fail
    stub_request(:post, "http://localhost:8001/payments")
      .to_return(status: 500, body: '{"error": "Service unavailable"}')

    stub_request(:post, "http://localhost:8002/payments")
      .to_return(status: 500, body: '{"error": "Service unavailable"}')

    params = {
      "correlationId" => @correlation_id,
      "amount" => @amount
    }

    double_json_format = double_json_format()
    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    # Payment creation should succeed even if external registration fails
    assert result.success?
    refute result.existing_payment_found
    assert result.payment.persisted?
    assert_nil result.payment.payment_service  # Should be nil due to service failure

    # Verify both services were attempted
    assert_requested :post, "http://localhost:8001/payments"
    assert_requested :post, "http://localhost:8002/payments"
  end

  test "stores amount correctly in cents internally" do
    # Stub both services to return success from default
    stub_request(:post, "http://localhost:8001/payments")
      .to_return(status: 200, body: '{"status": "success"}')

    params = {
      "correlationId" => @correlation_id,
      "amount" => 123.45
    }

    double_json_format = double_json_format()
    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert result.success?
    assert_equal 123.45, result.payment.amount  # Getter returns dollars
    assert_equal 12345, result.payment.amount_in_cents  # Internal storage in cents
  end

  private

  def double_json_format
    double = Object.new
    def double.json?
      true
    end
    double
  end

  def double_html_format
    double = Object.new
    def double.json?
      false
    end
    double
  end
end
