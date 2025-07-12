require "net/http"
require "json"
require "uri"
require_relative "payment_service_error"

module PaymentServices
  class BasePaymentService
    def initialize(base_url:, timeout: 30)
      @base_url = base_url
      @timeout = timeout
    end

    def register_payment(correlation_id:, amount:, requested_at: nil)
      requested_at ||= Time.current.iso8601(3)

      payload = {
        correlationId: correlation_id,
        amount: amount,
        requestedAt: requested_at
      }

      response = make_request(
        method: :post,
        path: "/payments",
        body: payload
      )

      parse_response(response)
    end

    private

    def make_request(method:, path:, body: nil)
      uri = URI.join(@base_url, path)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @timeout
      http.read_timeout = @timeout

      request = build_request(method, uri, body)

      Rails.logger.info "Making #{method.upcase} request to #{uri} (#{service_name})"
      Rails.logger.debug "Request body: #{body&.to_json}"

      response = http.request(request)

      Rails.logger.info "Payment service response: #{response.code} #{response.message} (#{service_name})"
      Rails.logger.debug "Response body: #{response.body}"

      response
    rescue Net::ReadTimeout, Net::OpenTimeout => e
      Rails.logger.error "Payment service timeout (#{service_name}): #{e.message}"
      raise PaymentServiceError.new("Payment service timeout", status_code: :timeout)
    rescue Net::HTTPError, SocketError => e
      Rails.logger.error "Payment service connection error (#{service_name}): #{e.message}"
      raise PaymentServiceError.new("Payment service connection error: #{e.message}")
    end

    def build_request(method, uri, body)
      request_class = case method
      when :post
        Net::HTTP::Post
      when :get
        Net::HTTP::Get
      when :put
        Net::HTTP::Put
      when :delete
        Net::HTTP::Delete
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end

      request = request_class.new(uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request["User-Agent"] = "PaymentProcessor/1.0"

      if body
        request.body = body.to_json
      end

      request
    end

    def parse_response(response)
      case response.code.to_i
      when 200..299
        if response.body.present?
          JSON.parse(response.body)
        else
          { "message" => "Success" }
        end
      when 400..499
        error_body = parse_error_body(response.body) || "Client error"
        raise PaymentServiceError.new(
          "Payment service client error: #{error_body}",
          status_code: response.code.to_i,
          response_body: response.body
        )
      when 500..599
        error_body = parse_error_body(response.body) || "Server error"
        raise PaymentServiceError.new(
          "Payment service server error: #{error_body}",
          status_code: response.code.to_i,
          response_body: response.body
        )
      else
        raise PaymentServiceError.new(
          "Unexpected response code: #{response.code}",
          status_code: response.code.to_i,
          response_body: response.body
        )
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse payment service response: #{e.message}"
      raise PaymentServiceError.new("Invalid response format from payment service")
    end

    def parse_error_body(body)
      return nil if body.blank?

      JSON.parse(body)
    rescue JSON::ParserError
      body
    end

    def service_name
      self.class.name.demodulize
    end
  end
end
