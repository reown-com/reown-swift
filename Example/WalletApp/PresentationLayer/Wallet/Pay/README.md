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
- **`PayOptionsView.swift`** - Payment options card list
- **`PayWhyInfoRequiredView.swift`** - "Why info required?" explanation dialog
- **`PayNameInputView.swift`** - Travel rule name capture
- **`PaySummaryView.swift`** - Post-IC payment summary/confirmation

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
WalletConnectPay.configure(projectId: InputConfig.projectId, apiKey: InputConfig.payApiKey!)
```

## Deep Link Format

```
walletapp://walletconnectpay?paymentId=<payment-id>
```

## Testing

### Manual Testing

#### Using the Card Button
1. Press the credit card button on the main wallet screen
2. Paste a payment URL like: `https://wc-pay-buyer-experience-dev.walletconnect-v1-bridge.workers.dev/?pid=pay_xxx`
3. Click "Start Payment" to begin the flow

#### Using Deep Link
```bash
# Test deep link in simulator
xcrun simctl openurl booted "walletapp://walletconnectpay?paymentId=test-123"
```

### Maestro E2E Tests

The Pay flow has comprehensive E2E tests using [Maestro](https://maestro.mobile.dev). Test flows are shared across all platforms (Swift, Kotlin, React Native) via the [`WalletConnect/actions`](https://github.com/WalletConnect/actions) repo.

#### Prerequisites

1. Install Maestro: `curl -Ls "https://get.maestro.mobile.dev" | bash`
2. Copy `.env.maestro.example` to `.env.maestro` at the repo root and fill in merchant credentials
3. Have an iOS simulator booted

#### Quick Start

```bash
# Download shared test flows
./scripts/setup-maestro-pay-tests.sh

# Build with test mode (adds URL input field + optional pre-funded wallet)
xcodebuild \
  -project "Example/ExampleApp.xcodeproj" \
  -scheme "WalletApp" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -derivedDataPath DerivedDataCache \
  RELAY_HOST='relay.walletconnect.com' \
  PROJECT_ID='<your-project-id>' \
  TEST_WALLET_PRIVATE_KEY='<your-funded-wallet-private-key>' \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) ENABLE_TEST_MODE' \
  build

# Install on simulator
xcrun simctl install booted "$(find DerivedDataCache -name 'WalletApp.app' -path '*/Debug-iphonesimulator/*' | head -1)"

# Run all Pay tests
./scripts/run-maestro-pay-tests.sh

# Or run a single test
./scripts/run-maestro-pay-tests.sh .maestro/pay_expired_link.yaml

# Or pass arbitrary Maestro args
./scripts/run-maestro-pay-tests.sh --device <sim-udid> .maestro/pay_expired_link.yaml

# Interactive debugging — inspect the view hierarchy
maestro studio
```

#### Test Mode (`ENABLE_TEST_MODE`)

The `ENABLE_TEST_MODE` Swift compilation flag enables two features:

1. **URL text input**: Adds a visible text field to the scanner options sheet, allowing Maestro to type payment URLs directly instead of scanning QR codes.
2. **Test wallet import**: If `TEST_WALLET_PRIVATE_KEY` is provided as a build setting, the app imports that EVM private key on launch instead of generating a random wallet. This allows CI to use a pre-funded wallet for Pay tests.

Both are passed via xcodebuild build settings — no Xcode project changes needed.

#### Accessibility Identifiers

All Pay views have accessibility identifiers that the shared Maestro test flows rely on. Key IDs:

| ID | View | Element |
|----|------|---------|
| `button-scan` | HeaderView | Scan button |
| `input-paste-url` | ScannerOptionsView | URL text field (test mode) |
| `button-submit-url` | ScannerOptionsView | Submit URL button (test mode) |
| `pay-merchant-info` | PayOptionsView / PaySummaryView | Merchant header |
| `pay-option-{index}` | PayOptionsView | Unselected option card |
| `pay-option-{index}-selected` | PayOptionsView | Selected option card |
| `pay-info-required-badge` | PayOptionsView | "Info required" pill |
| `pay-button-info` | PayOptionsView | Question mark button |
| `pay-button-continue` | PayOptionsView | Continue/Pay button |
| `pay-button-close` | All Pay views | Close (X) button |
| `pay-button-back` | PaySummaryView / PayWhyInfoRequiredView | Back arrow button |
| `pay-review-token-{networkName}` | PaySummaryView | Selected token row |
| `pay-button-pay` | PaySummaryView | Pay button |
| `pay-loading-message` | PayConfirmingView | Loading text |
| `pay-result-container` | PayResultView | Result container |
| `pay-result-success-icon` | PayResultView | Success checkmark |
| `pay-result-insufficient-funds-icon` | PayResultView | Insufficient funds icon |
| `pay-result-expired-icon` | PayResultView | Expired icon |
| `pay-result-cancelled-icon` | PayResultView | Cancelled icon |
| `pay-result-error-icon` | PayResultView | Generic error icon |
| `pay-button-result-action-{type}` | PayResultView | Result action button |

These IDs must stay in sync with `WalletConnect/actions/maestro/pay-tests`. If you change the UI, update the IDs accordingly.

#### CI

The GitHub Actions workflow `.github/workflows/ci_e2e_pay_tests.yml` runs these tests automatically on PRs. It builds with `ENABLE_TEST_MODE`, boots an iOS simulator, and runs the full Pay test suite.

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
