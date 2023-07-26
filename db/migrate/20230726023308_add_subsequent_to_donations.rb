class AddSubsequentToDonations < ActiveRecord::Migration[7.0]
  def change
    add_column :donations, :is_subsequent_recurring, :boolean
    add_column :donations, :expiry_month, :integer
    add_column :donations, :expiry_year, :integer
    add_column :donations, :executed_at, :datetime
  end
end
