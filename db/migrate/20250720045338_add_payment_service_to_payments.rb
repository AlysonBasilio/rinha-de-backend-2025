class AddPaymentServiceToPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :payment_service, :string
  end
end
