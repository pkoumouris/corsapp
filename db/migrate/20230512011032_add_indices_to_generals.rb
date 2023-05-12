class AddIndicesToGenerals < ActiveRecord::Migration[7.0]
  def change
    add_index :generals, :name, unique: true
  end
end
