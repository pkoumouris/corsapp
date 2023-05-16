class CreateDonations < ActiveRecord::Migration[7.0]
  def change
    create_table :donations do |t|
      t.integer :amount_in_cents
      t.string :gateway_response_code
      t.string :origin_ip
      t.string :currency
      t.boolean :success
      t.string :bank_transaction_spid
      t.string :email
      t.string :first_name
      t.string :last_name
      t.string :tracking_code_slug
      t.string :tracking_code
      t.string :address
      t.string :phone_number
      t.boolean :send_email_updates
      t.string :campaign
      t.string :campaign_name
      t.boolean :recurring
      t.boolean :imported_to_nb
      t.datetime :imported_to_nb_at
      t.boolean :exported
      t.string :order_spid
      t.string :gnaf_address_identifier
      t.string :other_data

      t.timestamps
    end
  end
end
