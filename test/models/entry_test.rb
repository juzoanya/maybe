  test "converted_amount with manual exchange rate calculates correctly" do
    family = families(:one)
    family.update!(currency: "EUR")
    
    account = family.accounts.create!(
      name: "Test Account",
      currency: "NGN",
      accountable: depositories(:one)
    )
    
    entry = account.entries.create!(
      date: Date.current,
      amount: 10000,
      currency: "NGN",
      exchange_rate: 0.000556,
      entryable: valuations(:one)
    )
    
    converted = entry.converted_amount
    assert_equal 5.56, converted.amount
    assert_equal "EUR", converted.currency.iso_code
  end 