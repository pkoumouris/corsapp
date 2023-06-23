class AddPageSlugToDonations < ActiveRecord::Migration[7.0]
  def change
    add_column :donations, :page_slug, :string
    add_index :donations, :created_at
  end
end
