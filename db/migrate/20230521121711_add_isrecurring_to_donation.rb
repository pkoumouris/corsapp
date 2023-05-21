class AddIsrecurringToDonation < ActiveRecord::Migration[7.0]
  def change
    remove_column :donations, :recurring
    add_column :donations, :is_recurring, :boolean
  end
end
