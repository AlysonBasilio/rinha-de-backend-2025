class AddCorrelationIdToPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :correlationId, :string
  end
end
