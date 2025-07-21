class AsyncPaymentCreationService
  def self.call(params:, request_format:)
    new(params: params, request_format: request_format).call
  end

  Result = Struct.new(:job_id, :correlation_id, :errors, keyword_init: true) do
    def success?
      errors.blank?
    end

    def accepted?
      job_id.present? && success?
    end
  end

  def initialize(params:, request_format:)
    @params = params
    @request_format = request_format
  end

  def call
    correlation_id, amount = extract_payment_params

    # Validate parameters before queuing
    validation_errors = validate_params(correlation_id, amount)
    if validation_errors.any?
      return Result.new(
        job_id: nil,
        correlation_id: correlation_id,
        errors: validation_errors
      )
    end

    # Queue the payment creation job
    job = PaymentCreationJob.perform_later(
      correlation_id: correlation_id,
      amount: amount,
      request_metadata: build_request_metadata
    )

    Result.new(
      job_id: job.job_id,
      correlation_id: correlation_id,
      errors: []
    )
  end

  private

  attr_reader :params, :request_format

  def extract_payment_params
    if json_request?
      [ params["correlationId"], params["amount"] ]
    else
      payment_params = params[:payment] || {}
      [ payment_params[:correlation_id], payment_params[:amount] ]
    end
  end

  def validate_params(correlation_id, amount)
    errors = []

    if correlation_id.blank?
      errors << "Correlation ID is required"
    elsif !correlation_id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
      errors << "Correlation ID must be a valid UUID"
    end

    if amount.blank?
      errors << "Amount is required"
    elsif amount.to_f <= 0
      errors << "Amount must be greater than 0"
    end

    errors
  end

  def build_request_metadata
    {
      user_agent: request_format.respond_to?(:headers) ? request_format.headers["User-Agent"] : nil,
      timestamp: Time.current.iso8601(3)
    }
  end

  def json_request?
    request_format&.json?
  end
end
