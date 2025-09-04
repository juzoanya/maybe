class AddExchangeRateToEntries < ActiveRecord::Migration[7.1]
  def change
    add_column :entries, :exchange_rate, :decimal, precision: 19, scale: 6
  end
end 