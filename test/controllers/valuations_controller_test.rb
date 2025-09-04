require "test_helper"

class ValuationsControllerTest < ActionDispatch::IntegrationTest
  include EntryableResourceInterfaceTest

  setup do
    sign_in @user = users(:family_admin)
    @entry = entries(:valuation)
  end

  test "can create reconciliation" do
    account = accounts(:investment)

    assert_difference [ "Entry.count", "Valuation.count" ], 1 do
      post valuations_url, params: {
        entry: {
          amount: account.balance + 100,
          date: Date.current.to_s,
          account_id: account.id
        }
      }
    end

    created_entry = Entry.order(created_at: :desc).first
    assert_equal "Manual value update", created_entry.name
    assert_equal Date.current, created_entry.date
    assert_equal account.balance + 100, created_entry.amount_money.to_f

    assert_enqueued_with job: SyncJob

    assert_redirected_to account_url(created_entry.account)
  end

  test "can create reconciliation with exchange rate" do
    account = accounts(:investment)

    assert_difference [ "Entry.count", "Valuation.count" ], 1 do
      post valuations_url, params: {
        entry: {
          amount: 1000,
          date: Date.current.to_s,
          account_id: account.id,
          currency: "EUR",
          exchange_rate: 1.1
        }
      }
    end

    created_entry = Entry.order(created_at: :desc).first
    assert_equal "Manual value update", created_entry.name
    assert_equal Date.current, created_entry.date
    assert_equal 1000, created_entry.amount_money.to_f
    assert_equal "EUR", created_entry.currency
    assert_equal 1.1, created_entry.exchange_rate

    assert_enqueued_with job: SyncJob

    assert_redirected_to account_url(created_entry.account)
  end

  test "can show valuation with exchange rate" do
    @entry.update!(currency: "EUR", exchange_rate: 1.1)
    
    get valuation_url(@entry)
    assert_response :success
    
    # Verify the form includes exchange rate field
    assert_select "input[name='entry[exchange_rate]'][value='1.1']"
    assert_select "input[name='entry[currency]'][value='EUR']"
  end

  test "updates entry with basic attributes" do
    assert_no_difference [ "Entry.count", "Valuation.count" ] do
      patch valuation_url(@entry), params: {
        entry: {
          amount: 22000,
          date: Date.current,
          notes: "Test notes"
        }
      }
    end

    assert_enqueued_with job: SyncJob

    assert_redirected_to account_url(@entry.account)

    @entry.reload
    assert_equal 22000, @entry.amount
    assert_equal "Test notes", @entry.notes
  end

  test "updates entry with exchange rate" do
    assert_no_difference [ "Entry.count", "Valuation.count" ] do
      patch valuation_url(@entry), params: {
        entry: {
          amount: 22000,
          date: Date.current,
          currency: "GBP",
          exchange_rate: 1.25
        }
      }
    end

    assert_enqueued_with job: SyncJob

    assert_redirected_to account_url(@entry.account)

    @entry.reload
    assert_equal 22000, @entry.amount
    assert_equal "GBP", @entry.currency
    assert_equal 1.25, @entry.exchange_rate
  end

  test "cannot update exchange rate once set" do
    @entry.update!(exchange_rate: 1.1)
    
    assert_no_difference [ "Entry.count", "Valuation.count" ] do
      patch valuation_url(@entry), params: {
        entry: {
          amount: 22000,
          date: Date.current,
          currency: "GBP",
          exchange_rate: 1.25  # This should be ignored
        }
      }
    end

    assert_enqueued_with job: SyncJob

    assert_redirected_to account_url(@entry.account)

    @entry.reload
    assert_equal 22000, @entry.amount
    assert_equal "GBP", @entry.currency
    assert_equal 1.1, @entry.exchange_rate  # Should remain unchanged
  end
end
