# db/migrate/20260316142400_create_api_keys.rb

class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys do |t|
      t.string :token, null: false       # token is required
      t.string :name, null: false        # name identifies who owns the key
      t.boolean :active, default: true   # new keys are active by default

      t.timestamps
    end

    # unique index — no two keys can be the same
    # also makes token lookups fast
    add_index :api_keys, :token, unique: true
  end
end