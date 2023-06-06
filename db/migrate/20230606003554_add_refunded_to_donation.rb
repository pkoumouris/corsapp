class AddRefundedToDonation < ActiveRecord::Migration[7.0]
  def change
    add_column :donations, :refunded, :boolean
    add_column :donations, :refunded_at, :datetime
  end
end
