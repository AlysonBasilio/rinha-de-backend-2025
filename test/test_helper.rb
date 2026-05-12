ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

# Allow localhost connections so Selenium/chromedriver can connect during system tests
# External connections (payment service URLs) are still blocked unless explicitly stubbed
WebMock.disable_net_connect!(allow_localhost: true)

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
    end
  end
end
