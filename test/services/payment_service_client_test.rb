require "test_helper"
require "webmock/minitest"

class PaymentServiceClientTest < ActiveSupport::TestCase
  def setup
    WebMock.reset!
    @client = PaymentServiceClient.new(base_url: "https://api.test.com")
    @correlation_id = "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b3"
    @amount = 19.90
  end

  def teardown
    WebMock.reset!
    ENV.delete("DEFAULT_PAYMENT_SERVICE_URL")
  end

  test "successful payment registration" do
    # Mock successful response
    stub_request(:post, "https://api.test.com/payments")
      .with(
        headers: {
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "User-Agent" => "PaymentProcessor/1.0"
        }
      )
      .to_return(
        status: 200,
        body: { message: "payment processed successfully" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.register_payment(
      correlation_id: @correlation_id,
      amount: @amount
    )

    assert_equal "payment processed successfully", result["message"]

    # Verify the request was made with correct data
    assert_requested(:post, "https://api.test.com/payments") do |req|
      body = JSON.parse(req.body)
      body["correlationId"] == @correlation_id &&
      body["amount"] == @amount &&
      body["requestedAt"] =~ /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/
    end
  end

  test "payment registration with custom requested_at" do
    custom_time = "2025-07-15T12:34:56.000Z"

    stub_request(:post, "https://api.test.com/payments")
      .to_return(
        status: 200,
        body: { message: "payment processed successfully" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.register_payment(
      correlation_id: @correlation_id,
      amount: @amount,
      requested_at: custom_time
    )

    assert_equal "payment processed successfully", result["message"]

    # Verify the request was made with correct data
    assert_requested(:post, "https://api.test.com/payments") do |req|
      body = JSON.parse(req.body)
      body["correlationId"] == @correlation_id &&
      body["amount"] == @amount &&
      body["requestedAt"] == custom_time
    end
  end

  test "handles client error response" do
    stub_request(:post, "https://api.test.com/payments")
      .to_return(
        status: 400,
        body: { error: "Invalid correlation ID" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(PaymentServices::PaymentServiceError) do
      @client.register_payment(
        correlation_id: "invalid",
        amount: @amount
      )
    end

    assert_includes error.message, "Payment service client error"
    assert_equal 400, error.status_code
  end

  test "handles server error response" do
    stub_request(:post, "https://api.test.com/payments")
      .to_return(
        status: 500,
        body: { error: "Internal server error" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(PaymentServices::PaymentServiceError) do
      @client.register_payment(
        correlation_id: @correlation_id,
        amount: @amount
      )
    end

    assert_includes error.message, "Payment service server error"
    assert_equal 500, error.status_code
  end

  test "handles timeout error" do
    stub_request(:post, "https://api.test.com/payments")
      .to_raise(Net::ReadTimeout)

    error = assert_raises(PaymentServices::PaymentServiceError) do
      @client.register_payment(
        correlation_id: @correlation_id,
        amount: @amount
      )
    end

    assert_includes error.message, "Payment service timeout"
    assert_equal :timeout, error.status_code
  end

  test "handles network error" do
    stub_request(:post, "https://api.test.com/payments")
      .to_raise(SocketError.new("Connection refused"))

    error = assert_raises(PaymentServices::PaymentServiceError) do
      @client.register_payment(
        correlation_id: @correlation_id,
        amount: @amount
      )
    end

    assert_includes error.message, "Payment service connection error"
  end

  test "handles invalid JSON response" do
    stub_request(:post, "https://api.test.com/payments")
      .to_return(
        status: 200,
        body: "invalid json",
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(PaymentServices::PaymentServiceError) do
      @client.register_payment(
        correlation_id: @correlation_id,
        amount: @amount
      )
    end

    assert_includes error.message, "Invalid response format from payment service"
  end

  test "handles empty response body" do
    stub_request(:post, "https://api.test.com/payments")
      .to_return(
        status: 200,
        body: "",
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.register_payment(
      correlation_id: @correlation_id,
      amount: @amount
    )

    assert_equal "Success", result["message"]
  end

  test "uses environment variable for base URL" do
    ENV["DEFAULT_PAYMENT_SERVICE_URL"] = "https://env.test.com"

    client = PaymentServiceClient.new

    stub_request(:post, "https://env.test.com/payments")
      .to_return(
        status: 200,
        body: { message: "payment processed successfully" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = client.register_payment(
      correlation_id: @correlation_id,
      amount: @amount
    )

    assert_equal "payment processed successfully", result["message"]
  end

  test "handles HTTP 201 Created response" do
    stub_request(:post, "https://api.test.com/payments")
      .to_return(
        status: 201,
        body: { message: "payment created successfully", id: "12345" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.register_payment(
      correlation_id: @correlation_id,
      amount: @amount
    )

    assert_equal "payment created successfully", result["message"]
    assert_equal "12345", result["id"]
  end

  test "handles client error with plain text response" do
    stub_request(:post, "https://api.test.com/payments")
      .to_return(
        status: 422,
        body: "Unprocessable Entity",
        headers: { "Content-Type" => "text/plain" }
      )

    error = assert_raises(PaymentServices::PaymentServiceError) do
      @client.register_payment(
        correlation_id: @correlation_id,
        amount: @amount
      )
    end

    assert_includes error.message, "Payment service client error"
    assert_equal 422, error.status_code
    assert_includes error.response_body, "Unprocessable Entity"
  end

  test "sends correct headers" do
    stub_request(:post, "https://api.test.com/payments")
      .with(
        headers: {
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "User-Agent" => "PaymentProcessor/1.0"
        }
      )
      .to_return(
        status: 200,
        body: { message: "success" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    @client.register_payment(
      correlation_id: @correlation_id,
      amount: @amount
    )

    # Assertion happens in the stub verification
    assert_requested(:post, "https://api.test.com/payments")
  end
end

class PaymentServiceRouterTest < ActiveSupport::TestCase
  def setup
    WebMock.reset!
    @correlation_id = "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b3"
    @amount = 19.90
  end

  def teardown
    WebMock.reset!
    ENV.delete("DEFAULT_PAYMENT_SERVICE_URL")
    ENV.delete("FALLBACK_PAYMENT_SERVICE_URL")
  end

  test "uses default service when available" do
    ENV["DEFAULT_PAYMENT_SERVICE_URL"] = "https://default.test.com"
    ENV["FALLBACK_PAYMENT_SERVICE_URL"] = "https://fallback.test.com"

    # Mock successful response from default service
    stub_request(:post, "https://default.test.com/payments")
      .to_return(
        status: 200,
        body: { message: "payment processed by default service" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    router = PaymentServices::PaymentServiceRouter.new

    result = router.register_payment(
      correlation_id: @correlation_id,
      amount: @amount
    )

    assert_equal "payment processed by default service", result["message"]
    assert_requested(:post, "https://default.test.com/payments")
    assert_not_requested(:post, "https://fallback.test.com/payments")
  ensure
    ENV.delete("DEFAULT_PAYMENT_SERVICE_URL")
    ENV.delete("FALLBACK_PAYMENT_SERVICE_URL")
  end

  test "falls back to fallback service when default service has server error" do
    ENV["DEFAULT_PAYMENT_SERVICE_URL"] = "https://default.test.com"
    ENV["FALLBACK_PAYMENT_SERVICE_URL"] = "https://fallback.test.com"

    # Mock server error from default service
    stub_request(:post, "https://default.test.com/payments")
      .to_return(
        status: 500,
        body: { error: "Internal server error" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Mock successful response from fallback service
    stub_request(:post, "https://fallback.test.com/payments")
      .to_return(
        status: 200,
        body: { message: "payment processed by fallback service" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    router = PaymentServices::PaymentServiceRouter.new

    result = router.register_payment(
      correlation_id: @correlation_id,
      amount: @amount
    )

    assert_equal "payment processed by fallback service", result["message"]
    assert_requested(:post, "https://default.test.com/payments")
    assert_requested(:post, "https://fallback.test.com/payments")
  ensure
    ENV.delete("DEFAULT_PAYMENT_SERVICE_URL")
    ENV.delete("FALLBACK_PAYMENT_SERVICE_URL")
  end

  test "falls back to fallback service when default service times out" do
    ENV["DEFAULT_PAYMENT_SERVICE_URL"] = "https://default.test.com"
    ENV["FALLBACK_PAYMENT_SERVICE_URL"] = "https://fallback.test.com"

    # Mock timeout from default service
    stub_request(:post, "https://default.test.com/payments")
      .to_raise(Net::ReadTimeout)

    # Mock successful response from fallback service
    stub_request(:post, "https://fallback.test.com/payments")
      .to_return(
        status: 200,
        body: { message: "payment processed by fallback service" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    router = PaymentServices::PaymentServiceRouter.new

    result = router.register_payment(
      correlation_id: @correlation_id,
      amount: @amount
    )

    assert_equal "payment processed by fallback service", result["message"]
    assert_requested(:post, "https://default.test.com/payments")
    assert_requested(:post, "https://fallback.test.com/payments")
  ensure
    ENV.delete("DEFAULT_PAYMENT_SERVICE_URL")
    ENV.delete("FALLBACK_PAYMENT_SERVICE_URL")
  end

  test "falls back to fallback service when default service has connection error" do
    ENV["DEFAULT_PAYMENT_SERVICE_URL"] = "https://default.test.com"
    ENV["FALLBACK_PAYMENT_SERVICE_URL"] = "https://fallback.test.com"

    # Mock connection error from default service
    stub_request(:post, "https://default.test.com/payments")
      .to_raise(SocketError.new("Connection refused"))

    # Mock successful response from fallback service
    stub_request(:post, "https://fallback.test.com/payments")
      .to_return(
        status: 200,
        body: { message: "payment processed by fallback service" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    router = PaymentServices::PaymentServiceRouter.new

    result = router.register_payment(
      correlation_id: @correlation_id,
      amount: @amount
    )

    assert_equal "payment processed by fallback service", result["message"]
    assert_requested(:post, "https://default.test.com/payments")
    assert_requested(:post, "https://fallback.test.com/payments")
  ensure
    ENV.delete("DEFAULT_PAYMENT_SERVICE_URL")
    ENV.delete("FALLBACK_PAYMENT_SERVICE_URL")
  end

  test "does not fallback for client errors" do
    ENV["DEFAULT_PAYMENT_SERVICE_URL"] = "https://default.test.com"
    ENV["FALLBACK_PAYMENT_SERVICE_URL"] = "https://fallback.test.com"

    # Mock client error from default service
    stub_request(:post, "https://default.test.com/payments")
      .to_return(
        status: 400,
        body: { error: "Invalid correlation ID" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    router = PaymentServices::PaymentServiceRouter.new

    error = assert_raises(PaymentServices::PaymentServiceError) do
      router.register_payment(
        correlation_id: "invalid",
        amount: @amount
      )
    end

    assert_includes error.message, "Payment service client error"
    assert_equal 400, error.status_code
    assert_requested(:post, "https://default.test.com/payments")
    assert_not_requested(:post, "https://fallback.test.com/payments")
  ensure
    ENV.delete("DEFAULT_PAYMENT_SERVICE_URL")
    ENV.delete("FALLBACK_PAYMENT_SERVICE_URL")
  end

  test "raises error when both services fail" do
    ENV["DEFAULT_PAYMENT_SERVICE_URL"] = "https://default.test.com"
    ENV["FALLBACK_PAYMENT_SERVICE_URL"] = "https://fallback.test.com"

    # Mock server error from default service
    stub_request(:post, "https://default.test.com/payments")
      .to_return(
        status: 500,
        body: { error: "Internal server error" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Mock server error from fallback service
    stub_request(:post, "https://fallback.test.com/payments")
      .to_return(
        status: 500,
        body: { error: "Internal server error" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    router = PaymentServices::PaymentServiceRouter.new

    error = assert_raises(PaymentServices::PaymentServiceError) do
      router.register_payment(
        correlation_id: @correlation_id,
        amount: @amount
      )
    end

    assert_includes error.message, "Payment service server error"
    assert_equal 500, error.status_code
    assert_requested(:post, "https://default.test.com/payments")
    assert_requested(:post, "https://fallback.test.com/payments")
  ensure
    ENV.delete("DEFAULT_PAYMENT_SERVICE_URL")
    ENV.delete("FALLBACK_PAYMENT_SERVICE_URL")
  end
end

class DefaultPaymentServiceTest < ActiveSupport::TestCase
  def setup
    WebMock.reset!
    ENV["DEFAULT_PAYMENT_SERVICE_URL"] = "https://default.test.com"
    @service = PaymentServices::DefaultPaymentService.new
    @correlation_id = "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b3"
    @amount = 19.90
  end

  def teardown
    WebMock.reset!
    ENV.delete("DEFAULT_PAYMENT_SERVICE_URL")
  end

  test "uses correct base URL from environment" do
    stub_request(:post, "https://default.test.com/payments")
      .to_return(
        status: 200,
        body: { message: "success" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    @service.register_payment(
      correlation_id: @correlation_id,
      amount: @amount
    )

    assert_requested(:post, "https://default.test.com/payments")
  end

  test "uses default URL when environment variable not set" do
    ENV.delete("DEFAULT_PAYMENT_SERVICE_URL")
    service = PaymentServices::DefaultPaymentService.new

    stub_request(:post, "http://localhost:8001/payments")
      .to_return(
        status: 200,
        body: { message: "success" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    service.register_payment(
      correlation_id: @correlation_id,
      amount: @amount
    )

    assert_requested(:post, "http://localhost:8001/payments")
  end
end

class FallbackPaymentServiceTest < ActiveSupport::TestCase
  def setup
    WebMock.reset!
    ENV["FALLBACK_PAYMENT_SERVICE_URL"] = "https://fallback.test.com"
    @service = PaymentServices::FallbackPaymentService.new
    @correlation_id = "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b3"
    @amount = 19.90
  end

  def teardown
    WebMock.reset!
    ENV.delete("FALLBACK_PAYMENT_SERVICE_URL")
  end

  test "uses correct base URL from environment" do
    stub_request(:post, "https://fallback.test.com/payments")
      .to_return(
        status: 200,
        body: { message: "success" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    @service.register_payment(
      correlation_id: @correlation_id,
      amount: @amount
    )

    assert_requested(:post, "https://fallback.test.com/payments")
  end

  test "uses default URL when environment variable not set" do
    ENV.delete("FALLBACK_PAYMENT_SERVICE_URL")
    service = PaymentServices::FallbackPaymentService.new

    stub_request(:post, "http://localhost:8002/payments")
      .to_return(
        status: 200,
        body: { message: "success" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    service.register_payment(
      correlation_id: @correlation_id,
      amount: @amount
    )

    assert_requested(:post, "http://localhost:8002/payments")
  end
end
