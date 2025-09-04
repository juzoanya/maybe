# Manual Exchange Rates for Valuations (Opening Balances)

## Overview

This feature allows users to manually specify exchange rates for valuation entries (opening balances) that are in a different currency than their family's preferred currency. This is particularly useful for accounts denominated in foreign currencies where automatic exchange rate providers may not have reliable data.

## How it Works

### When the Feature is Active

The manual exchange rate field appears automatically when:
1. A user selects a currency different from their family's preferred currency in the valuation form
2. The valuation form detects the currency mismatch

### User Experience

1. **Currency Selection**: When creating a valuation (opening balance), users can select any currency from the dropdown
2. **Exchange Rate Field**: If the selected currency differs from the family currency, an exchange rate field appears
3. **Manual Input**: Users can enter the exchange rate in the format "1 [CURRENCY] = [RATE] [FAMILY_CURRENCY]"
4. **Validation**: The exchange rate must be a positive number with up to 6 decimal places

### Example

- Family currency: USD
- Valuation currency: EUR
- Exchange rate: 1.1 (meaning 1 EUR = 1.1 USD)
- Valuation amount: 1000 EUR
- Converted amount: 1100 USD

## Technical Implementation

### Model Changes

- `Entry` model already includes validation for exchange_rate (must be positive)
- `Account::ReconciliationManager` now accepts `currency` and `exchange_rate` parameters
- `Account::Reconcileable` concern updated to pass currency and exchange_rate parameters

### Controller Changes

- `ValuationsController` now accepts `exchange_rate` and `currency` parameters
- Properly handles the exchange rate in create/update actions

### Frontend Changes

- Valuation form now includes currency selection (removed `disable_currency: true`)
- Added exchange rate field that appears when currency differs from family currency
- Uses the same `transaction-form` Stimulus controller as transaction forms
- Form shows/hides exchange rate field based on currency selection

### Database

- Uses existing `exchange_rate` column in `entries` table (decimal, precision: 19, scale: 6)
- Allows storing manual exchange rates for individual valuation entries

## Usage

When adding an opening balance for an account:

1. Navigate to the account page
2. Click "Add balance update"
3. Select the currency (if different from family currency)
4. Enter the amount
5. If currency differs from family currency, enter the exchange rate
6. Confirm the balance update

The system will store both the original amount in the selected currency and the exchange rate for accurate conversion to the family's preferred currency. 