class BalanceSheet::NetWorthSeriesBuilder
  def initialize(family)
    @family = family
  end

  def net_worth_series(period: Period.last_30_days)
    Rails.cache.fetch(cache_key(period)) do
      builder = Balance::ChartSeriesBuilder.new(
        account_ids: visible_account_ids,
        currency: family.currency,
        period: period,
        favorable_direction: "up"
      )

      builder.balance_series
    end
  end

  private
    attr_reader :family

    def visible_account_ids
      @visible_account_ids ||= family.accounts.visible.with_attached_logo.pluck(:id)
    end

    def cache_key(period)
      # Include manual exchange rates in cache key to invalidate when they change
      latest_manual_exchange_rate_entry = family.entries
        .where.not(exchange_rate: nil)
        .order(:updated_at)
        .last

      manual_exchange_rate_timestamp = latest_manual_exchange_rate_entry&.updated_at&.to_i || 0
      current_timestamp = Time.current.to_i

      key = [
        "balance_sheet_net_worth_series",
        period.start_date,
        period.end_date,
        "manual_exchange_rates_#{manual_exchange_rate_timestamp}",
        "v2_timestamp_#{current_timestamp}"
      ].compact.join("_")

      family.build_cache_key(
        key,
        invalidate_on_data_updates: true
      )
    end
end
