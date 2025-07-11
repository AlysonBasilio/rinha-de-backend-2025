class RenameAmountToAmountInCents < ActiveRecord::Migration[8.0]
  def change
    rename_column :payments, :amount, :amount_in_cents
  end
end
