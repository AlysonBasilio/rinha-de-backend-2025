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

  test "should create payment" do
    assert_difference("Payment.count") do
      post payments_url, params: { payment: { amount: @payment.amount, correlation_id: "50505050-5050-5050-5050-505050505050" } }
    end

    assert_redirected_to payment_url(Payment.last)
  end

  test "should create payment with amount conversion" do
    assert_difference("Payment.count") do
      post payments_url, params: { payment: { amount: 19.99, correlation_id: "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b4" } }
    end

    payment = Payment.last
    assert_equal 1999, payment.amount_in_cents
    assert_equal 19.99, payment.amount
    assert_equal "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b4", payment.correlation_id
    assert_redirected_to payment_url(payment)
  end

  test "should create payment via JSON API" do
    assert_difference("Payment.count") do
      post payments_url(format: :json),
        params: { correlationId: "550e8400-e29b-41d4-a716-446655440000", amount: 25.99 }.to_json,
        headers: { "Content-Type": "application/json", "Accept": "application/json" }
    end

    assert_response :created
    payment = Payment.last
    assert_equal "550e8400-e29b-41d4-a716-446655440000", payment.correlation_id
    assert_equal 2599, payment.amount_in_cents
  end

  test "should return existing payment for duplicate correlationId (idempotency)" do
    # First request creates the payment
    post payments_url(format: :json),
      params: { correlationId: "550e8400-e29b-41d4-a716-446655440001", amount: 30.50 }.to_json,
      headers: { "Content-Type": "application/json", "Accept": "application/json" }

    assert_response :created
    first_payment = Payment.last
    first_response = response.body

    # Second request with same correlationId should return the same payment
    assert_no_difference("Payment.count") do
      post payments_url(format: :json),
        params: { correlationId: "550e8400-e29b-41d4-a716-446655440001", amount: 30.50 }.to_json,
        headers: { "Content-Type": "application/json", "Accept": "application/json" }
    end

    assert_response :created
    assert_equal first_response, response.body
  end

  test "should return existing payment even with different amount (idempotency)" do
    # First request creates the payment
    post payments_url(format: :json),
      params: { correlationId: "550e8400-e29b-41d4-a716-446655440002", amount: 15.75 }.to_json,
      headers: { "Content-Type": "application/json", "Accept": "application/json" }

    assert_response :created
    first_payment = Payment.last
    original_amount = first_payment.amount

    # Second request with same correlationId but different amount should return original payment
    assert_no_difference("Payment.count") do
      post payments_url(format: :json),
        params: { correlationId: "550e8400-e29b-41d4-a716-446655440002", amount: 999.99 }.to_json,
        headers: { "Content-Type": "application/json", "Accept": "application/json" }
    end

    assert_response :created
    response_data = JSON.parse(response.body)
    assert_equal original_amount, response_data["amount"]
    assert_equal first_payment.id, response_data["id"]
  end

  test "should return JSON for created payment" do
    post payments_url(format: :json),
      params: { correlationId: "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b6", amount: 19.90 }.to_json,
      headers: { "Content-Type": "application/json", "Accept": "application/json" }

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b6", json_response["correlationId"]
    assert_equal 19.90, json_response["amount"]
  end

  test "should return validation errors for invalid JSON payment" do
    post payments_url(format: :json),
      params: { amount: 19.90 }.to_json,  # Missing correlationId
      headers: { "Content-Type": "application/json", "Accept": "application/json" }

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_includes json_response["correlation_id"], "can't be blank"
  end

  test "should return validation errors for invalid UUID" do
    post payments_url(format: :json),
      params: { correlationId: "not-a-valid-uuid", amount: 19.90 }.to_json,
      headers: { "Content-Type": "application/json", "Accept": "application/json" }

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_includes json_response["correlation_id"], "must be a valid UUID"
  end

  test "should return existing payment for duplicate UUID (idempotency)" do
    # Create first payment
    post payments_url(format: :json),
      params: { correlationId: "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b7", amount: 19.90 }.to_json,
      headers: { "Content-Type": "application/json", "Accept": "application/json" }
    assert_response :created
    first_payment = Payment.last
    first_response = response.body

    # Second request with same UUID should return the same payment
    assert_no_difference("Payment.count") do
      post payments_url(format: :json),
        params: { correlationId: "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b7", amount: 29.90 }.to_json,
        headers: { "Content-Type": "application/json", "Accept": "application/json" }
    end

    assert_response :created
    assert_equal first_response, response.body
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
    patch payment_url(@payment), params: { payment: { amount: @payment.amount, correlation_id: @payment.correlation_id } }
    assert_redirected_to payment_url(@payment)
  end

  test "should update payment with amount conversion" do
    original_amount = @payment.amount_in_cents
    new_amount = 45.67

    patch payment_url(@payment), params: { payment: { amount: new_amount, correlation_id: @payment.correlation_id } }

    @payment.reload
    assert_equal 4567, @payment.amount_in_cents
    assert_equal 45.67, @payment.amount
    assert_redirected_to payment_url(@payment)
  end

  test "should update payment via JSON API" do
    patch payment_url(@payment, format: :json),
      params: { correlationId: "60606060-6060-6060-6060-606060606060", amount: 99.99 }.to_json,
      headers: { "Content-Type": "application/json", "Accept": "application/json" }

    @payment.reload
    assert_equal 9999, @payment.amount_in_cents
    assert_equal 99.99, @payment.amount
    assert_equal "60606060-6060-6060-6060-606060606060", @payment.correlation_id
    assert_response :ok
  end

  test "should destroy payment" do
    assert_difference("Payment.count", -1) do
      delete payment_url(@payment)
    end

    assert_redirected_to payments_url
  end

  test "should handle string amount in create" do
    assert_difference("Payment.count") do
      post payments_url, params: { payment: { amount: "123.45", correlation_id: "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b8" } }
    end

    payment = Payment.last
    assert_equal 12345, payment.amount_in_cents
    assert_equal 123.45, payment.amount
    assert_equal "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b8", payment.correlation_id
  end

  test "should handle zero amount validation" do
    assert_no_difference("Payment.count") do
      post payments_url, params: { payment: { amount: 0, correlation_id: "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b9" } }
    end

    assert_response :unprocessable_entity
  end
end
