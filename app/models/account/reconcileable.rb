module Account::Reconcileable
  extend ActiveSupport::Concern

  def create_reconciliation(balance:, date:, dry_run: false, currency: nil, exchange_rate: nil)
    result = reconciliation_manager.reconcile_balance(balance: balance, date: date, dry_run: dry_run, currency: currency, exchange_rate: exchange_rate)
    sync_later if result.success? && !dry_run
    result
  end

  def update_reconciliation(existing_valuation_entry, balance:, date:, dry_run: false, currency: nil, exchange_rate: nil)
    result = reconciliation_manager.reconcile_balance(balance: balance, date: date, existing_valuation_entry: existing_valuation_entry, dry_run: dry_run, currency: currency, exchange_rate: exchange_rate)
    sync_later if result.success? && !dry_run
    result
  end

  private
    def reconciliation_manager
      @reconciliation_manager ||= Account::ReconciliationManager.new(self)
    end
end
