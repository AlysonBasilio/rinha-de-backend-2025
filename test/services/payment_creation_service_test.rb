require "test_helper"
require "webmock/minitest"

class PaymentCreationServiceTest < ActiveSupport::TestCase
  def setup
    super  # Call parent setup to get global WebMock stubs
    @base_correlation_id = "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b"
    @amount = 19.90
    # Clean up any existing test data
    Payment.where("correlation_id LIKE ?", "#{@base_correlation_id}%").delete_all
  end

  test "creates new payment successfully with JSON params and calls external service" do
    correlation_id = @base_correlation_id + "1"
    params = {
      "correlationId" => correlation_id,
      "amount" => @amount
    }

    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert result.success?
    assert result.newly_created
    assert_not result.idempotent?
    assert_equal correlation_id, result.payment.correlation_id
    assert_equal @amount, result.payment.amount
    assert_equal "default", result.payment.payment_service
    assert result.payment.persisted?

    # Verify external service was called
    assert_requested :post, "http://localhost:8001/payments", times: 1
  end

  test "creates new payment successfully with HTML params and calls external service" do
    correlation_id = @base_correlation_id + "2"
    params = {
      payment: {
        correlation_id: correlation_id,
        amount: @amount
      }
    }

    service = PaymentCreationService.new(params: params, request_format: double_html_format)
    result = service.call

    assert result.success?
    assert result.newly_created
    assert_not result.idempotent?
    assert_equal correlation_id, result.payment.correlation_id
    assert_equal @amount, result.payment.amount
    assert_equal "default", result.payment.payment_service
    assert result.payment.persisted?

    # Verify external service was called
    assert_requested :post, "http://localhost:8001/payments", times: 1
  end

  test "returns existing payment for duplicate correlation_id (idempotency) without calling external service" do
    correlation_id = @base_correlation_id + "3"

    # Create initial payment
    existing_payment = Payment.create!(
      correlation_id: correlation_id,
      amount: @amount
    )

    # Reset WebMock to clear any previous requests
    WebMock.reset!

    # Re-establish the default stubs since we reset WebMock
    stub_request(:post, "http://localhost:8001/payments")
      .to_return(
        status: 200,
        body: { message: "payment processed successfully" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:post, "http://localhost:8002/payments")
      .to_return(
        status: 200,
        body: { message: "payment processed successfully" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    params = {
      "correlationId" => correlation_id,
      "amount" => 50.0  # Different amount
    }

    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert result.success?
    assert_not result.newly_created
    assert result.idempotent?
    assert_equal existing_payment.id, result.payment.id
    assert_equal @amount, result.payment.amount  # Should keep original amount
    assert_nil result.payment.payment_service  # Should not be set for existing payments

    # Verify external service was NOT called
    assert_not_requested :post, "http://localhost:8001/payments"
    assert_not_requested :post, "http://localhost:8002/payments"
  end

  test "returns errors for invalid payment" do
    params = {
      "correlationId" => "invalid-uuid",  # Invalid UUID format
      "amount" => @amount
    }

    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert_not result.success?
    assert_not result.newly_created
    assert_not result.idempotent?
    assert_not result.payment.persisted?
    assert result.errors.present?
    assert_includes result.errors.join, "Correlation"
  end

  test "handles missing correlation_id" do
    params = {
      "amount" => @amount
    }

    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert_not result.success?
    assert_not result.newly_created
    assert_not result.idempotent?
    assert_not result.payment.persisted?
    assert result.errors.present?
  end

  test "handles missing amount" do
    correlation_id = @base_correlation_id + "4"
    params = {
      "correlationId" => correlation_id
    }

    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert_not result.success?
    assert_not result.newly_created
    assert_not result.idempotent?
    assert_not result.payment.persisted?
    assert result.errors.present?
  end

  test "handles empty params gracefully" do
    params = {}

    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert_not result.success?
    assert_not result.newly_created
    assert_not result.idempotent?
    assert_not result.payment.persisted?
    assert result.errors.present?
  end

  test "handles string amounts correctly" do
    correlation_id = @base_correlation_id + "5"
    params = {
      "correlationId" => correlation_id,
      "amount" => "25.50"
    }

    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert result.success?
    assert result.newly_created
    assert_equal 25.50, result.payment.amount
    assert_equal "default", result.payment.payment_service
    assert result.payment.persisted?
  end

  test "sets payment_service to 'default' when default service is used" do
    correlation_id = @base_correlation_id + "6"
    params = {
      "correlationId" => correlation_id,
      "amount" => @amount
    }

    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert result.success?
    assert result.newly_created
    assert_equal "default", result.payment.payment_service
  end

  test "sets payment_service to 'fallback' when fallback service is used" do
    correlation_id = @base_correlation_id + "7"
    params = {
      "correlationId" => correlation_id,
      "amount" => @amount
    }

    # Stub the default service to fail with a timeout (service unavailable)
    WebMock.reset!
    stub_request(:post, "http://localhost:8001/payments")
      .to_timeout

    # Stub the fallback service to succeed
    stub_request(:post, "http://localhost:8002/payments")
      .with(
        body: hash_including({
          "correlationId" => correlation_id,
          "amount" => @amount
        }),
        headers: {
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "User-Agent" => "PaymentProcessor/1.0"
        }
      )
      .to_return(status: 200, body: { success: true }.to_json)

    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert result.success?
    assert result.newly_created
    assert_equal "fallback", result.payment.payment_service
  end

  test "does not set payment_service for existing payments (idempotency)" do
    correlation_id = @base_correlation_id + "8"

    # Create initial payment without payment_service
    existing_payment = Payment.create!(
      correlation_id: correlation_id,
      amount: @amount
    )
    assert_nil existing_payment.payment_service

    params = {
      "correlationId" => correlation_id,
      "amount" => @amount
    }

    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert result.success?
    assert_not result.newly_created
    assert result.idempotent?
    assert_equal existing_payment.id, result.payment.id
    # Should still be nil since we didn't register with external service
    assert_nil result.payment.payment_service
  end

  test "payment creation succeeds even if external service registration fails" do
    correlation_id = @base_correlation_id + "9"
    params = {
      "correlationId" => correlation_id,
      "amount" => @amount
    }

    # Stub all external services to fail with non-retryable errors
    WebMock.reset!
    stub_request(:post, "http://localhost:8001/payments")
      .to_return(status: 400, body: { error: "Bad request" }.to_json)

    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    # Payment creation should still succeed even if external service fails
    assert result.success?
    assert result.newly_created
    assert result.payment.persisted?
    assert_equal correlation_id, result.payment.correlation_id
    assert_equal @amount, result.payment.amount
    # payment_service might be nil if external registration failed
  end

  test "stores amount correctly in cents internally" do
    correlation_id = @base_correlation_id + "0"
    amount_dollars = 12.34
    params = {
      "correlationId" => correlation_id,
      "amount" => amount_dollars
    }

    service = PaymentCreationService.new(params: params, request_format: double_json_format)
    result = service.call

    assert result.success?, "Expected payment creation to succeed, but got errors: #{result.errors}"
    assert_equal amount_dollars, result.payment.amount
    assert_equal 1234, result.payment.amount_in_cents
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
