class AddForeignKeyToRecurring < ActiveRecord::Migration[7.0]
  def change
    add_reference :donations, :recurring, foreign_key: true
  end
end
