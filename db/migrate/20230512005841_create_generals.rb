class CreateGenerals < ActiveRecord::Migration[7.0]
  def change
    create_table :generals do |t|
      t.string :name
      t.string :value
      t.boolean :current

      t.timestamps
    end
  end
end
