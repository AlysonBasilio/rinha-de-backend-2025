class Payment < ApplicationRecord
  validates :correlation_id, presence: true, uniqueness: true, format: {
    with: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i,
    message: "must be a valid UUID"
  }
  validates :amount_in_cents, presence: true, numericality: { greater_than: 0 }
  validates :payment_service, inclusion: { in: [ "default", "fallback" ] }, allow_nil: true

  # Helper method to get amount in dollars
  def amount
    amount_in_cents ? amount_in_cents / 100.0 : 0.0
  end

  # Helper method to set amount from dollars
  def amount=(dollars)
    self.amount_in_cents = (dollars.to_f * 100).round
  end

  # Helper method to format amount as currency
  def formatted_amount
    amount_in_cents ? "$#{sprintf('%.2f', amount_in_cents / 100.0)}" : "$0.00"
  end
end
