class AddStatusToPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :status, :integer, default: 0, null: false

    # Update existing payments to have completed status if they have a payment_service
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE payments
          SET status = 2
          WHERE payment_service IS NOT NULL
        SQL
      end
    end
  end
end
