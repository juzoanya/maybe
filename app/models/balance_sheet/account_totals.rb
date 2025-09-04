class BalanceSheet::AccountTotals
  def initialize(family, sync_status_monitor:)
    @family = family
    @sync_status_monitor = sync_status_monitor
  end

  def asset_accounts
    @asset_accounts ||= account_rows.filter { |t| t.classification == "asset" }
  end

  def liability_accounts
    @liability_accounts ||= account_rows.filter { |t| t.classification == "liability" }
  end

  private
    attr_reader :family, :sync_status_monitor

    AccountRow = Data.define(:account, :converted_balance, :is_syncing) do
      def syncing? = is_syncing

      # Allows Rails path helpers to generate URLs from the wrapper
      def to_param = account.to_param
      delegate_missing_to :account
    end

    def visible_accounts
      @visible_accounts ||= family.accounts.visible.with_attached_logo
    end

    def account_rows
      @account_rows ||= query.map do |account_row|
        AccountRow.new(
          account: account_row,
          converted_balance: calculate_converted_balance(account_row),
          is_syncing: sync_status_monitor.account_syncing?(account_row)
        )
      end
    end

    def calculate_converted_balance(account)
      # If account currency matches family currency, no conversion needed
      balance_money = account.balance_money
      return Money.new(0, family.currency) if balance_money.nil?
      return balance_money if account.currency == family.currency

      # Check if there are any entries with manual exchange rates for this account
      manual_exchange_rate_entry = account.entries
        .where.not(exchange_rate: nil)
        .where.not(currency: family.currency)
        .order(:date)
        .last

      if manual_exchange_rate_entry&.exchange_rate.present?
        # Use the manual exchange rate from the most recent entry
        converted_amount = (balance_money.amount * manual_exchange_rate_entry.exchange_rate).round(2)
        Money.new(converted_amount, family.currency)
      else
        # Fallback to automatic exchange rate from the database
        balance_money.exchange_to(family.currency, fallback_rate: 1)
      end
    end

    def cache_key
      # Include entries with exchange rates in cache key to invalidate when manual rates change
      latest_exchange_rate_entry = family.entries
        .where.not(exchange_rate: nil)
        .order(:updated_at)
        .last

      exchange_rate_timestamp = latest_exchange_rate_entry&.updated_at&.to_i || 0
      current_timestamp = Time.current.to_i

      family.build_cache_key(
        "balance_sheet_account_rows_exchange_rate_#{exchange_rate_timestamp}_v2_timestamp_#{current_timestamp}",
        invalidate_on_data_updates: true
      )
    end

    def query
      @query ||= Rails.cache.fetch(cache_key) do
        visible_accounts.to_a
      end
    end
end
