class CreateRecurrings < ActiveRecord::Migration[7.0]
  def change
    create_table :recurrings do |t|
      t.string :customer_code
      t.string :schedule_spid
      t.integer :amount
      t.boolean :active
      t.string :last_digits
      t.integer :expiry_month
      t.integer :expiry_year
      t.string :card_scheme
      t.string :payment_interval_type

      t.timestamps
    end
  end
end
