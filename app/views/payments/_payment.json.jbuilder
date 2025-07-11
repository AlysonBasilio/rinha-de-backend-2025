json.extract! payment, :id, :created_at, :updated_at
json.correlationId payment.correlation_id
json.amount payment.amount
json.url payment_url(payment, format: :json)
