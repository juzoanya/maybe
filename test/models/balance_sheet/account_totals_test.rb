require "test_helper"

class BalanceSheet::AccountTotalsTest < ActiveSupport::TestCase
  setup do
    @family = families(:one)
    @family.update!(currency: "EUR")
    @sync_status_monitor = SyncStatusMonitor.new(@family)
  end

  test "calculates converted balance using manual exchange rate from entries" do
    account = @family.accounts.create!(
      name: "Test Account", currency: "USD", balance: 1000, accountable: depositories(:one)
    )
    account.entries.create!(
      date: Date.current, name: "Opening balance", amount: 1000, currency: "USD", exchange_rate: 0.85, entryable: valuations(:one)
    )
    totals = BalanceSheet::AccountTotals.new(@family, sync_status_monitor: @sync_status_monitor)
    account_row = totals.asset_accounts.find { |row| row.account == account }
    assert_equal 850, account_row.converted_balance.cents
    assert_equal "EUR", account_row.converted_balance.currency.iso_code
  end

  test "balance sheet uses corrected exchange rate calculation" do
    account = @family.accounts.create!(
      name: "Test Account", currency: "NGN", balance: 10000, accountable: depositories(:one)
    )
    account.entries.create!(
      date: Date.current, name: "Opening balance", amount: 10000, currency: "NGN", exchange_rate: 0.000556, entryable: valuations(:one)
    )
    totals = BalanceSheet::AccountTotals.new(@family, sync_status_monitor: @sync_status_monitor)
    account_row = totals.asset_accounts.find { |row| row.account == account }
    assert_equal 5.56, account_row.converted_balance.amount
    assert_equal "EUR", account_row.converted_balance.currency.iso_code
  end

  test "falls back to automatic exchange rate when no manual rate exists" do
    # Create an account in a different currency
    account = @family.accounts.create!(
      name: "Test Account",
      currency: "USD",
      balance: 1000,
      accountable: depositories(:one)
    )

    # Create a valuation entry without manual exchange rate
    account.entries.create!(
      date: Date.current,
      name: "Opening balance",
      amount: 1000,
      currency: "USD",
      exchange_rate: nil,
      entryable: valuations(:one)
    )

    totals = BalanceSheet::AccountTotals.new(@family, sync_status_monitor: @sync_status_monitor)
    account_row = totals.asset_accounts.find { |row| row.account == account }

    # Should use automatic conversion (fallback rate of 1)
    assert_equal 1000, account_row.converted_balance.cents
    assert_equal "EUR", account_row.converted_balance.currency.iso_code
  end

  test "uses most recent manual exchange rate when multiple entries exist" do
    # Create an account in a different currency
    account = @family.accounts.create!(
      name: "Test Account",
      currency: "USD",
      balance: 1000,
      accountable: depositories(:one)
    )

    # Create older entry with manual exchange rate
    account.entries.create!(
      date: 1.day.ago,
      name: "Old balance",
      amount: 1000,
      currency: "USD",
      exchange_rate: 0.80,
      entryable: valuations(:one)
    )

    # Create newer entry with different manual exchange rate
    account.entries.create!(
      date: Date.current,
      name: "New balance",
      amount: 1000,
      currency: "USD",
      exchange_rate: 0.90,
      entryable: valuations(:one)
    )

    totals = BalanceSheet::AccountTotals.new(@family, sync_status_monitor: @sync_status_monitor)
    account_row = totals.asset_accounts.find { |row| row.account == account }

    # Should use the most recent manual exchange rate: 1000 USD * 0.90 = 900 EUR
    assert_equal 900, account_row.converted_balance.cents
    assert_equal "EUR", account_row.converted_balance.currency.iso_code
  end

  test "no conversion needed when account currency matches family currency" do
    # Create an account in the same currency as family
    account = @family.accounts.create!(
      name: "Test Account",
      currency: "EUR",
      balance: 1000,
      accountable: depositories(:one)
    )

    totals = BalanceSheet::AccountTotals.new(@family, sync_status_monitor: @sync_status_monitor)
    account_row = totals.asset_accounts.find { |row| row.account == account }

    # Should return original balance without conversion
    assert_equal 1000, account_row.converted_balance.cents
    assert_equal "EUR", account_row.converted_balance.currency.iso_code
  end
end 