require "test_helper"

class AsyncPaymentsControllerTest < ActionDispatch::IntegrationTest
  test "should create payment asynchronously via JSON API" do
    correlation_id = SecureRandom.uuid

    assert_enqueued_with(job: PaymentCreationJob) do
      post payments_url, params: {
        correlationId: correlation_id,
        amount: 123.45
      }.to_json, headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    end

    assert_response :accepted

    response_body = JSON.parse(response.body)
    assert_equal "accepted", response_body["status"]
    assert_equal correlation_id, response_body["correlation_id"]
    assert response_body["job_id"].present?
  end

  test "should queue job for duplicate correlation ID - idempotency handled by job" do
    correlation_id = SecureRandom.uuid
    Payment.create!(
      correlation_id: correlation_id,
      amount_in_cents: 12345,
      status: :completed,
      payment_service: "default"
    )

    # Service should still queue a job for duplicate - let job handle idempotency
    assert_enqueued_with(job: PaymentCreationJob) do
      post payments_url, params: {
        correlationId: correlation_id,
        amount: 123.45
      }.to_json, headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    end

    assert_response :accepted

    response_body = JSON.parse(response.body)
    assert_equal "accepted", response_body["status"]
    assert_equal correlation_id, response_body["correlation_id"]
    assert response_body["job_id"].present?
  end

  test "should return validation errors for async requests" do
    post payments_url, params: {
      correlationId: "invalid-uuid",
      amount: 123.45
    }.to_json, headers: { "Content-Type" => "application/json", "Accept" => "application/json" }

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert response_body["errors"].present?
    assert response_body["errors"].include?("Correlation ID must be a valid UUID")
  end

  test "should use synchronous processing for HTML requests" do
    # HTML requests should still work synchronously
    correlation_id = SecureRandom.uuid

    assert_difference "Payment.count", 1 do
      post payments_url, params: {
        payment: {
          correlation_id: correlation_id,
          amount: 123.45
        }
      }
    end

    assert_redirected_to payment_path(Payment.last)
  end
end
