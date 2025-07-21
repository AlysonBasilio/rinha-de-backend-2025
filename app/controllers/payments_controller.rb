class PaymentsController < ApplicationController
  before_action :set_payment, only: %i[ show edit update destroy ]

  # Skip CSRF protection for JSON API requests
  skip_before_action :verify_authenticity_token, if: :json_request?

  # GET /payments or /payments.json
  def index
    @payments = Payment.all
  end

  # GET /payments/1 or /payments/1.json
  def show
  end

  # GET /payments/new
  def new
    @payment = Payment.new
  end

  # GET /payments/1/edit
  def edit
  end

  # POST /payments or /payments.json
  def create
    # Use async processing for JSON API requests, sync for HTML forms
    if json_request?
      create_async
    else
      create_sync
    end
  end

  # PATCH/PUT /payments/1 or /payments/1.json
  def update
    correlation_id, amount = extract_payment_params

    # Update payment attributes
    update_payment_attributes(correlation_id, amount)
    render_update_response
  end

  # DELETE /payments/1 or /payments/1.json
  def destroy
    @payment.destroy!

    respond_to do |format|
      format.html { redirect_to payments_path, status: :see_other, notice: "Payment was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  def create_async
    result = AsyncPaymentCreationService.call(params: params, request_format: request.format)

    respond_to do |format|
      if result.success?
        # Return job info for async processing
        format.json {
          render json: {
            status: "accepted",
            message: "Payment creation queued for processing",
            correlation_id: result.correlation_id,
            job_id: result.job_id
          }, status: :accepted
        }
      else
        format.json { render json: { errors: result.errors }, status: :unprocessable_entity }
      end
    end
  end

  def create_sync
    service = PaymentCreationService.new(params: params, request_format: request.format)
    result = service.call

    @payment = result.payment

    respond_to do |format|
      if result.success?
        format.html { redirect_to @payment, notice: "Payment was successfully created." }
        format.json { render :show, status: :created, location: @payment }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @payment.errors, status: :unprocessable_entity }
      end
    end
  end

    # Use callbacks to share common setup or constraints between actions.
    def set_payment
      @payment = Payment.find(params.expect(:id))
    end

    # Extract payment parameters based on request type
    def extract_payment_params
      if json_request?
        [ params["correlationId"], params["amount"] ]
      else
        payment_params = params[:payment] || {}
        [ payment_params[:correlation_id], payment_params[:amount] ]
      end
    end

    # Update payment attributes based on provided parameters
    def update_payment_attributes(correlation_id, amount)
      @payment.correlation_id = correlation_id if correlation_id.present?
      @payment.amount = amount if amount.present?
    end

    # Render appropriate response for update action
    def render_update_response
      respond_to do |format|
        if @payment.save
          format.html { redirect_to @payment, notice: "Payment was successfully updated." }
          format.json { render :show, status: :ok, location: @payment }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @payment.errors, status: :unprocessable_entity }
        end
      end
    end

    # Check if request is JSON
    def json_request?
      request.format.json?
    end
end
