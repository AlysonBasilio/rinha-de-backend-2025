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
    correlation_id, amount = extract_payment_params

    # Check for existing payment (idempotency)
    existing_payment = find_existing_payment(correlation_id)
    if existing_payment
      @payment = existing_payment
      render_payment_response
      return
    end

    # Create new payment
    @payment = build_payment(correlation_id, amount)
    render_payment_response
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

    # Find existing payment by correlation_id for idempotency
    def find_existing_payment(correlation_id)
      return nil unless correlation_id.present?
      Payment.find_by(correlation_id: correlation_id)
    end

    # Build new payment with given parameters
    def build_payment(correlation_id, amount)
      payment = Payment.new
      payment.correlation_id = correlation_id
      payment.amount = amount if amount.present?
      payment
    end

    # Render appropriate response based on payment save result
    def render_payment_response
      respond_to do |format|
        if @payment.persisted? || @payment.save
          format.html { redirect_to @payment, notice: "Payment was successfully created." }
          format.json { render :show, status: :created, location: @payment }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @payment.errors, status: :unprocessable_entity }
        end
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
