require "test_helper"

class AccountTest < ActiveSupport::TestCase
  include SyncableInterfaceTest, EntriesTestHelper

  setup do
    @account = @syncable = accounts(:depository)
    @family = families(:dylan_family)
  end

  test "can destroy" do
    assert_difference "Account.count", -1 do
      @account.destroy
    end
  end

  test "gets short/long subtype label" do
    account = @family.accounts.create!(
      name: "Test Investment",
      balance: 1000,
      currency: "USD",
      subtype: "hsa",
      accountable: Investment.new
    )

    assert_equal "HSA", account.short_subtype_label
    assert_equal "Health Savings Account", account.long_subtype_label

    # Test with nil subtype
    account.update!(subtype: nil)
    assert_equal "Investments", account.short_subtype_label
    assert_equal "Investments", account.long_subtype_label
  end

  test "balance_money returns correct Money object" do
    account = accounts(:one)
    account.update!(balance: 1000.50, currency: "USD")
    
    balance_money = account.balance_money
    assert_equal 100050, balance_money.cents
    assert_equal "USD", balance_money.currency.iso_code
  end

  test "balance_money handles zero balance" do
    account = accounts(:one)
    account.update!(balance: 0, currency: "EUR")
    
    balance_money = account.balance_money
    assert_equal 0, balance_money.cents
    assert_equal "EUR", balance_money.currency.iso_code
  end

  test "balance_money returns nil for nil balance" do
    account = accounts(:one)
    account.update!(balance: nil, currency: "USD")
    
    balance_money = account.balance_money
    assert_nil balance_money
  end

  test "money cents method works correctly" do
    account = accounts(:one)
    account.update!(balance: 1000.50, currency: "USD")
    
    balance_money = account.balance_money
    assert_equal 100050, balance_money.cents
  end

  test "money to_d method works correctly" do
    account = accounts(:one)
    account.update!(balance: 1000.50, currency: "USD")
    
    balance_money = account.balance_money
    assert_equal BigDecimal("1000.5"), balance_money.to_d
  end

  test "money ceil method works correctly" do
    account = accounts(:one)
    account.update!(balance: 1000.50, currency: "USD")
    
    balance_money = account.balance_money
    assert_equal 1001, balance_money.ceil
  end

  test "money abs method works correctly" do
    account = accounts(:one)
    account.update!(balance: -1000.50, currency: "USD")
    
    balance_money = account.balance_money
    abs_money = balance_money.abs
    assert_equal 1000.50, abs_money.amount
    assert_equal "USD", abs_money.currency.iso_code
  end
end
