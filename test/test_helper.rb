ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Setup WebMock stubs for external payment service APIs
    def setup
      super

      # Stub default payment service API calls
      stub_request(:post, "https://api.defaultpayment.com/payments")
        .to_return(
          status: 200,
          body: { message: "payment processed successfully" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "https://api.fallbackpayment.com/payments")
        .to_return(
          status: 200,
          body: { message: "payment processed successfully" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Keep the original stub for backward compatibility
      stub_request(:post, "https://api.paymentservice.com/payments")
        .to_return(
          status: 200,
          body: { message: "payment processed successfully" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end
  end
end
