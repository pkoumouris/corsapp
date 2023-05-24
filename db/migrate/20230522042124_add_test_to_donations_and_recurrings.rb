class AddTestToDonationsAndRecurrings < ActiveRecord::Migration[7.0]
  def change
    add_column :donations, :test, :boolean
    add_column :recurrings, :test, :boolean
    add_column :donations, :signup_nbid, :string
    add_index :donations, :nbid
  end
end
