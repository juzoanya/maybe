class ValuationsController < ApplicationController
  include EntryableResource, StreamExtensions

  def confirm_create
    @account = Current.family.accounts.find(params.dig(:entry, :account_id))
    @entry = @account.entries.build(entry_params.merge(currency: @account.currency))

    @reconciliation_dry_run = @entry.account.create_reconciliation(
      balance: entry_params[:amount],
      date: entry_params[:date],
      currency: entry_params[:currency],
      exchange_rate: entry_params[:exchange_rate],
      dry_run: true
    )

    render :confirm_create
  end

  def confirm_update
    @entry = Current.family.entries.find(params[:id])
    @account = @entry.account
    @entry.assign_attributes(entry_params.merge(currency: @account.currency))

    @reconciliation_dry_run = @entry.account.update_reconciliation(
      @entry,
      balance: entry_params[:amount],
      date: entry_params[:date],
      currency: entry_params[:currency],
      exchange_rate: entry_params[:exchange_rate],
      dry_run: true
    )

    render :confirm_update
  end

  def create
    account = Current.family.accounts.find(params.dig(:entry, :account_id))

    result = account.create_reconciliation(
      balance: entry_params[:amount],
      date: entry_params[:date],
      currency: entry_params[:currency],
      exchange_rate: entry_params[:exchange_rate],
    )

    if result.success?
      respond_to do |format|
        format.html { redirect_back_or_to account_path(account), notice: "Account updated" }
        format.turbo_stream { stream_redirect_back_or_to(account_path(account), notice: "Account updated") }
      end
    else
      @error_message = result.error_message
      render :new, status: :unprocessable_entity
    end
  end

  def update
    # Notes updating is independent of reconciliation, just a simple CRUD operation
    @entry.update!(notes: entry_params[:notes]) if entry_params[:notes].present?

    if entry_params[:date].present? && entry_params[:amount].present?
      # Don't allow updating exchange rate if it's already set
      update_params = entry_params.except(:exchange_rate) if @entry.exchange_rate.present?
      update_params ||= entry_params
      
      result = @entry.account.update_reconciliation(
        @entry,
        balance: update_params[:amount],
        date: update_params[:date],
        currency: update_params[:currency],
        exchange_rate: update_params[:exchange_rate],
      )
    end

    if result.nil? || result.success?
      @entry.reload

      respond_to do |format|
        format.html { redirect_back_or_to account_path(@entry.account), notice: "Entry updated" }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              dom_id(@entry, :header),
              partial: "valuations/header",
              locals: { entry: @entry }
            ),
            turbo_stream.replace(@entry)
          ]
        end
      end
    else
      @error_message = result.error_message
      render :show, status: :unprocessable_entity
    end
  end

  private
    def entry_params
      params.require(:entry).permit(:date, :amount, :notes, :exchange_rate, :currency)
    end
end
