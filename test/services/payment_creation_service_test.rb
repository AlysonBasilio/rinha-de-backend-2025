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

  test "creates new payment successfully with JSON params" do
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
    assert result.payment.persisted?
  end

  test "creates new payment successfully with HTML params" do
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
    assert result.payment.persisted?
  end

  test "returns existing payment for duplicate correlation_id (idempotency)" do
    correlation_id = @base_correlation_id + "3"

    # Create initial payment
    existing_payment = Payment.create!(
      correlation_id: correlation_id,
      amount: @amount
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
    assert result.payment.persisted?
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
