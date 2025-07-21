require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @payment = payments(:one)
  end

  test "should get index" do
    get payments_url
    assert_response :success
  end

  test "should get new" do
    get new_payment_url
    assert_response :success
  end

  test "should create payment via HTML form" do
    assert_difference("Payment.count") do
      post payments_url, params: { payment: { correlation_id: "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b4", amount: 19.99 } }
    end

    assert_response :redirect

    payment = Payment.last
    assert_equal 1999, payment.amount_in_cents
    assert_equal 19.99, payment.amount
    assert_equal "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b4", payment.correlation_id
    assert_redirected_to payment_url(payment)
  end

  test "should create payment via JSON API asynchronously" do
    # JSON API requests are processed asynchronously, so no immediate Payment.count change
    assert_enqueued_with(job: PaymentCreationJob) do
      post payments_url(format: :json),
        params: { correlationId: "550e8400-e29b-41d4-a716-446655440000", amount: 25.99 }.to_json,
        headers: { "Content-Type": "application/json", "Accept": "application/json" }
    end

    assert_response :accepted  # 202 Accepted for async processing
    json_response = JSON.parse(response.body)
    assert_equal "accepted", json_response["status"]
    assert_equal "Payment creation queued for processing", json_response["message"]
    assert_equal "550e8400-e29b-41d4-a716-446655440000", json_response["correlation_id"]
    assert json_response["job_id"].present?
  end

  test "should return existing payment for duplicate correlationId (idempotency)" do
    # Create first payment via HTML form (synchronous)
    post payments_url, params: { payment: { correlation_id: "550e8400-e29b-41d4-a716-446655440001", amount: 19.90 } }
    assert_response :redirect

    # Second request via JSON API with same correlationId should still queue job
    assert_enqueued_with(job: PaymentCreationJob) do
      post payments_url(format: :json),
        params: { correlationId: "550e8400-e29b-41d4-a716-446655440001", amount: 50.0 }.to_json,
        headers: { "Content-Type": "application/json", "Accept": "application/json" }
    end

    assert_response :accepted  # Async processing always returns 202
    json_response = JSON.parse(response.body)
    assert_equal "accepted", json_response["status"]
    assert_equal "550e8400-e29b-41d4-a716-446655440001", json_response["correlation_id"]
  end

  test "should return existing payment even with different amount (idempotency)" do
    # Create first payment via HTML form
    post payments_url, params: { payment: { correlation_id: "550e8400-e29b-41d4-a716-446655440002", amount: 19.90 } }
    assert_response :redirect

    # Second request with different amount but same correlationId
    assert_enqueued_with(job: PaymentCreationJob) do
      post payments_url(format: :json),
        params: { correlationId: "550e8400-e29b-41d4-a716-446655440002", amount: 99.99 }.to_json,
        headers: { "Content-Type": "application/json", "Accept": "application/json" }
    end

    assert_response :accepted
    json_response = JSON.parse(response.body)
    assert_equal "accepted", json_response["status"]
    assert_equal "550e8400-e29b-41d4-a716-446655440002", json_response["correlation_id"]
  end

  test "should show payment" do
    get payment_url(@payment)
    assert_response :success
  end

  test "should get edit" do
    get edit_payment_url(@payment)
    assert_response :success
  end

  test "should update payment" do
    patch payment_url(@payment), params: { payment: { correlation_id: @payment.correlation_id } }
    assert_redirected_to payment_url(@payment)
  end

  test "should destroy payment" do
    assert_difference("Payment.count", -1) do
      delete payment_url(@payment)
    end

    assert_redirected_to payments_url
  end

  test "should return JSON for async payment creation" do
    assert_enqueued_with(job: PaymentCreationJob) do
      post payments_url(format: :json),
        params: { correlationId: "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b6", amount: 19.90 }.to_json,
        headers: { "Content-Type": "application/json", "Accept": "application/json" }
    end

    assert_response :accepted  # Async processing
    json_response = JSON.parse(response.body)
    assert_equal "accepted", json_response["status"]
    assert_equal "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b6", json_response["correlation_id"]
    assert json_response["job_id"].present?
  end

    test "should return validation errors for invalid JSON payment" do
    # AsyncPaymentCreationService validates before queuing jobs
    post payments_url(format: :json),
      params: { amount: 19.90 }.to_json,  # Missing correlationId
      headers: { "Content-Type": "application/json", "Accept": "application/json" }

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response["errors"].present?
    assert json_response["errors"].any? { |error| error.include?("Correlation ID") }
  end

  test "should return validation errors for invalid UUID" do
    # AsyncPaymentCreationService validates before queuing jobs
    post payments_url(format: :json),
      params: { correlationId: "not-a-valid-uuid", amount: 19.90 }.to_json,
      headers: { "Content-Type": "application/json", "Accept": "application/json" }

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response["errors"].present?
    assert json_response["errors"].any? { |error| error.include?("UUID") }
  end

  test "should return async response for duplicate UUID" do
    # Create first payment via HTML form
    post payments_url, params: { payment: { correlation_id: "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b7", amount: 19.90 } }
    assert_response :redirect

    # Second request with same UUID via JSON API
    assert_enqueued_with(job: PaymentCreationJob) do
      post payments_url(format: :json),
        params: { correlationId: "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b7", amount: 25.00 }.to_json,
        headers: { "Content-Type": "application/json", "Accept": "application/json" }
    end

    assert_response :accepted
    json_response = JSON.parse(response.body)
    assert_equal "accepted", json_response["status"]
    assert_equal "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b7", json_response["correlation_id"]
  end

  test "should display payment" do
    get payment_url(@payment, format: :json)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal @payment.correlation_id, json_response["correlationId"]
    assert_equal @payment.amount, json_response["amount"]
  end

  test "should list payments as JSON" do
    get payments_url(format: :json)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Array)

    if json_response.any?
      first_payment = json_response.first
      assert first_payment.key?("correlationId")
      assert first_payment.key?("amount")
    end
  end

  test "should handle HTML form validation errors" do
    # HTML forms still get synchronous validation
    post payments_url, params: { payment: { correlation_id: "invalid-uuid", amount: 19.90 } }
    assert_response :unprocessable_entity
  end

  test "should handle HTML form missing correlation_id" do
    # HTML forms still get synchronous validation
    post payments_url, params: { payment: { amount: 19.90 } }
    assert_response :unprocessable_entity
  end

  test "should handle HTML form missing amount" do
    # HTML forms still get synchronous validation
    post payments_url, params: { payment: { correlation_id: "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b8" } }
    assert_response :unprocessable_entity
  end
end
