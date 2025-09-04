require "test_helper"

class EntryTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @entry = entries :transaction
  end

  test "entry cannot be older than 10 years ago" do
    assert_raises ActiveRecord::RecordInvalid do
      @entry.update! date: 50.years.ago.to_date
    end
  end

  test "valuations cannot have more than one entry per day" do
    existing_valuation = entries :valuation

    new_valuation = Entry.new \
      entryable: Valuation.new(kind: "reconciliation"),
      account: existing_valuation.account,
      date: existing_valuation.date, # invalid
      currency: existing_valuation.currency,
      amount: existing_valuation.amount

    assert new_valuation.invalid?
  end

  test "triggers sync with correct start date when transaction is set to prior date" do
    prior_date = @entry.date - 1
    @entry.update! date: prior_date

    @entry.account.expects(:sync_later).with(window_start_date: prior_date)
    @entry.sync_account_later
  end

  test "triggers sync with correct start date when transaction is set to future date" do
    prior_date = @entry.date
    @entry.update! date: @entry.date + 1

    @entry.account.expects(:sync_later).with(window_start_date: prior_date)
    @entry.sync_account_later
  end

  test "triggers sync with correct start date when transaction deleted" do
    @entry.destroy!

    @entry.account.expects(:sync_later).with(window_start_date: nil)
    @entry.sync_account_later
  end

  test "can search entries" do
    family = families(:empty)
    account = family.accounts.create! name: "Test", balance: 0, currency: "USD", accountable: Depository.new
    category = family.categories.first
    merchant = family.merchants.first

    create_transaction(account: account, name: "a transaction")
    create_transaction(account: account, name: "ignored")
    create_transaction(account: account, name: "third transaction", category: category, merchant: merchant)

    params = { search: "a" }

    assert_equal 2, family.entries.search(params).size

    params = { search: "%" }
    assert_equal 0, family.entries.search(params).size
  end

  test "visible scope only returns entries from visible accounts" do
    # Create transactions for all account types
    visible_transaction = create_transaction(account: accounts(:depository), name: "Visible transaction")
    invisible_transaction = create_transaction(account: accounts(:credit_card), name: "Invisible transaction")

    # Update account statuses
    accounts(:credit_card).disable!

    # Test the scope
    visible_entries = Entry.visible

    # Should include entry from active account
    assert_includes visible_entries, visible_transaction

    # Should not include entry from disabled account
    assert_not_includes visible_entries, invisible_transaction
  end

  test "needs_manual_exchange_rate returns true when currency differs from family currency" do
    @entry.account.family.update!(currency: "USD")
    @entry.update!(currency: "EUR")
    
    assert @entry.needs_manual_exchange_rate?
  end

  test "needs_manual_exchange_rate returns false when currency matches family currency" do
    @entry.account.family.update!(currency: "USD")
    @entry.update!(currency: "USD")
    
    assert_not @entry.needs_manual_exchange_rate?
  end

  test "converted_amount uses manual exchange rate when present" do
    @entry.account.family.update!(currency: "USD")
    @entry.update!(currency: "EUR", amount: 100, exchange_rate: 1.2)
    
    assert_equal 120, @entry.converted_amount
  end

  test "converted_amount falls back to automatic conversion when no manual rate" do
    @entry.account.family.update!(currency: "USD")
    @entry.update!(currency: "EUR", amount: 100, exchange_rate: nil)
    
    # Should use automatic conversion (fallback rate of 1)
    assert_equal 100, @entry.converted_amount
  end

  test "converted_amount returns original amount when currencies match" do
    @entry.account.family.update!(currency: "USD")
    @entry.update!(currency: "USD", amount: 100)
    
    assert_equal 100, @entry.converted_amount
  end
end
