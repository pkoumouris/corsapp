class AddIndicesToGenerals < ActiveRecord::Migration[7.0]
  def change
    add_index :generals, :name, unique: true
    add_index :donations, :gateway_response_code
    add_index :donations, :success
    add_index :donations, :email
    add_index :donations, :tracking_code
    add_index :donations, :imported_to_nb
    add_index :donations, :exported
    add_index :donations, :order_spid
    add_index :donations, :bank_transaction_spid
    add_index :donations, :customer_code
  end
end
