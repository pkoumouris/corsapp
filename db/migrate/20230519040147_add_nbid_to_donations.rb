class AddNbidToDonations < ActiveRecord::Migration[7.0]
  def change
    add_column :donations, :nbid, :string # add index
    remove_index :donations, :customer_code
  end
end
