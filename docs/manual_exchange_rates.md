# Manual Exchange Rates for Transactions

## Overview

This feature allows users to manually specify exchange rates for transactions that are in a different currency than their family's preferred currency. This is particularly useful for transactions in currencies like NGN (Nigerian Naira) where automatic exchange rate providers may not have reliable data.

## How it Works

### When the Feature is Active

The manual exchange rate field appears automatically when:
1. A user selects a currency different from their family's preferred currency
2. The transaction form detects the currency mismatch

### User Experience

1. **Currency Selection**: When creating a transaction, users can select any currency from the dropdown
2. **Exchange Rate Field**: If the selected currency differs from the family currency, an exchange rate field appears
3. **Manual Input**: Users can enter the exchange rate in the format "1 [CURRENCY] = [RATE] [FAMILY_CURRENCY]"
4. **Validation**: The exchange rate must be a positive number with up to 6 decimal places

### Example

- Family currency: USD
- Transaction currency: NGN
- Exchange rate: 0.0025 (meaning 1 NGN = 0.0025 USD)
- Transaction amount: 1000 NGN
- Converted amount: 2.50 USD

## Technical Implementation

### Database Changes

- Added `exchange_rate` column to `entries` table (decimal, precision: 19, scale: 6)
- Allows storing manual exchange rates for individual transactions

### Model Changes

- `Entry` model includes validation for exchange_rate (must be positive)
- Added `needs_manual_exchange_rate?` method to check if manual rate is needed
- Added `converted_amount` method that uses manual rate when available

### Controller Changes

- `TransactionsController` now accepts `exchange_rate` parameter
- Properly handles the exchange rate in create/update actions

### Frontend Changes

- Stimulus controller (`transaction_form_controller.js`) handles dynamic field visibility
- Form shows/hides exchange rate field based on currency selection
- Real-time validation and user feedback

## Benefits

1. **Accuracy**: Users can specify exact exchange rates for their transactions
2. **Flexibility**: Works with any currency combination
3. **Fallback**: Still uses automatic exchange rates when manual rate is not provided
4. **User Control**: Gives users control over currency conversion for important transactions

## Future Enhancements

- Historical exchange rate lookup as suggestions
- Bulk exchange rate updates
- Exchange rate validation against known rates
- Support for different exchange rate sources 