class RenameCorrelationIdToCorrelationIdWithUnique < ActiveRecord::Migration[8.0]
  def change
    rename_column :payments, :correlationId, :correlation_id
    add_index :payments, :correlation_id, unique: true
  end
end
