import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["exchangeRateField", "currencySelect", "amountField", "selectedCurrency"]

  connect() {
    this.toggleExchangeRateField()
  }

  currencyChanged() {
    this.toggleExchangeRateField()
  }

  toggleExchangeRateField() {
    const selectedCurrency = this.currencySelectTarget.value
    const familyCurrency = this.element.dataset.familyCurrency
    const accountCurrency = this.element.dataset.accountCurrency
    
    // If currency select is disabled, use account currency
    const currency = selectedCurrency || accountCurrency
    
    if (currency && familyCurrency && currency !== familyCurrency) {
      // Only show/hide if the field has the 'hidden' class (for new forms)
      if (this.exchangeRateFieldTarget.classList.contains('hidden')) {
        this.exchangeRateFieldTarget.classList.remove("hidden")
      }
      this.exchangeRateFieldTarget.querySelector("input").required = true
      this.selectedCurrencyTarget.textContent = currency
    } else {
      // Only hide if the field has the 'hidden' class (for new forms)
      if (this.exchangeRateFieldTarget.classList.contains('hidden')) {
        this.exchangeRateFieldTarget.classList.add("hidden")
      }
      this.exchangeRateFieldTarget.querySelector("input").required = false
    }
  }
} 