# Pay Integration

## Overview

The Pay module integrates with the WalletConnectPay SDK to handle payment flows in the wallet app.

## Architecture

### SDK Package (`Sources/WalletConnectPay/`)

The `WalletConnectPay` package wraps the Yttrium pay client and provides:

- **`WalletConnectPay`** - Singleton entry point (similar to `WalletKit`)
- **`PayClient`** - Client with documented methods:
  - `getPaymentOptions(paymentLink:accounts:includePaymentInfo:)` - Fetch payment options
  - `getRequiredPaymentActions(paymentId:optionId:)` - Get actions needed to complete payment
  - `confirmPayment(paymentId:optionId:results:maxPollMs:)` - Confirm payment with signatures

### Example App (`Example/WalletApp/.../Pay/`)

- **`PayModule.swift`** - VIPER module factory
- **`PayPresenter.swift`** - State management, calls `WalletConnectPay.instance` directly
- **`PayRouter.swift`** - Navigation
- **`PayService.swift`** - Helper extensions for formatting
- **`PayContainerView.swift`** - Step container
- **`PayIntroView.swift`** - Screen 104: Payment intro
- **`PayNameInputView.swift`** - Screen 105: Travel rule name capture
- **`PayConfirmView.swift`** - Screen 107: Payment confirmation

## Payment Flow

1. **Deep Link / QR Code** → App receives payment link
2. **`WalletConnectPay.instance.getPaymentOptions`** → Fetch merchant info and available payment options
3. **User selects option** → Choose asset/network for payment
4. **`WalletConnectPay.instance.getRequiredPaymentActions`** → Get required signatures (permits, etc.)
5. **Sign actions** → For `eth_signTypedData_v4` actions, sign the typed data
6. **`WalletConnectPay.instance.confirmPayment`** → Submit signatures and confirm payment

## Action Types

Required actions (`Action` enum):
- **`walletRpc`** - RPC actions like `eth_signTypedData_v4` for permit signing
- **`collectData`** - Data collection actions (e.g., first name, last name for travel rule)

The `PaymentSigner` protocol defines the signing interface:

```swift
protocol PaymentSigner {
    func signTypedData(chainId: String, params: String) async throws -> String
}
```

## Configuration

### Package Setup

In `Package.swift`, set `yttriumDebug = true` to use the local yttrium repo (required until Pay types are published):

```swift
let yttriumDebug = true  // Use local ../yttrium
```

### App Configuration

WalletConnectPay is configured in `SceneDelegate.swift`:

```swift
WalletConnectPay.configure(projectId: InputConfig.projectId)
```

## Deep Link Format

```
walletapp://walletconnectpay?paymentId=<payment-id>
```

## Testing

### Using the Card Button
1. Press the credit card button on the main wallet screen
2. Paste a payment URL like: `https://wc-pay-buyer-experience-dev.walletconnect-v1-bridge.workers.dev/?pid=pay_xxx`
3. Click "Start Payment" to begin the flow

### Using Deep Link
```bash
# Test deep link in simulator
xcrun simctl openurl booted "walletapp://walletconnectpay?paymentId=test-123"
```

## Yttrium Types

The following types from Yttrium are used directly (no FFI wrappers needed):

- `PaymentOptionsResponse` - Response from getPaymentOptions
- `PaymentOption` - Individual payment option with `actions: [Action]`
- `PaymentInfo` - Payment details (amount, merchant, status)
- `Action` - Action to perform (`walletRpc` or `collectData`)
- `WalletRpcAction` - RPC action with method and params
- `CollectDataAction` - Data collection action with fields
- `ConfirmPaymentResultItem` - Result item (`walletRpc` or `collectData`)
- `WalletRpcResultData` - RPC result with method and data array
- `CollectDataResultData` - Collected data fields
- `ConfirmPaymentResultResponse` - Confirmation result
- `SdkConfig` - Configuration for WalletConnectPay client

## TODO

- [ ] Implement proper EIP-712 typed data signing in `ETHSigner`
- [ ] Add QR code scanning support for payment links
- [ ] Add success/failure confirmation screens
- [ ] Handle payment expiration gracefully
- [ ] Publish yttrium version with Pay types (then set `yttriumDebug = false`)

