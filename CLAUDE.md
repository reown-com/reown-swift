# CLAUDE.md

Guidance for AI agents working on this repository.

## Related Repositories

**Yttrium** - Rust SDK used as a dependency in this project
- Location: `../yttrium` (sibling directory)
- This Swift SDK uses Yttrium's XCFramework for Pay and other features
- **Important:** Never make changes to yttrium repo without explicit user approval

## Build & Development

```bash
# Build the project
swift build

# Build with Xcode
xcodebuild -scheme <scheme_name>
```

## Project Structure

This is the Reown Swift SDK repository containing iOS/macOS SDKs for WalletConnect services.

## Maestro E2E Pay Tests

The wallet sample app includes Maestro E2E tests for WalletConnect Pay flows. The shared test flows are downloaded from `WalletConnect/actions` repo at runtime.

### Prerequisites

- [Maestro CLI](https://maestro.mobile.dev) installed
- iOS simulator booted
- Merchant API credentials in `.env.maestro` (copy from `.env.maestro.example`)

### Setup & Run

```bash
# 1. Download shared test flows
./scripts/setup-maestro-pay-tests.sh

# 2. Build with test mode enabled (optionally with a pre-funded wallet)
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

# 3. Install on simulator
xcrun simctl boot "iPhone 16" 2>/dev/null || true
xcrun simctl install booted "$(find DerivedDataCache -name 'WalletApp.app' -path '*/Debug-iphonesimulator/*' | head -1)"

# 4. Run tests
./scripts/run-maestro-pay-tests.sh
```

### Test Mode

The `ENABLE_TEST_MODE` Swift compilation flag enables two features:
- **URL text input**: Adds a visible text field to the scanner options sheet, allowing Maestro to type payment URLs directly instead of scanning QR codes.
- **Test wallet import**: If `TEST_WALLET_PRIVATE_KEY` is provided as a build setting, the app imports that EVM private key on launch instead of generating a random wallet. This allows CI to use a pre-funded wallet for Pay tests.

Both are passed via xcodebuild build settings — no Xcode project changes needed.

### Accessibility Identifiers

All Pay UI views have accessibility identifiers matching the shared Maestro test flows (e.g., `pay-button-pay`, `pay-option-0-selected`, `pay-result-success-icon`). These IDs must stay in sync with `WalletConnect/actions/maestro/pay-tests`.

Important: for custom SwiftUI `Shape`/wrapper content, putting `.accessibilityIdentifier(...)` on an arbitrary SwiftUI container is not always enough for Maestro/XCUITest on iOS. The Pay result icons and KYC badge had to be exposed on underlying native accessible elements (`UIImageView` / `UILabel`) before Maestro could reliably find them. If a visible element is failing by `id`, verify the identifier is attached to the actual native accessibility element, not just a SwiftUI wrapper.

#### Stable option ids (`pay-option-{symbol}-{network}`)

Payment-option rows carry both the order-dependent `pay-option-{index}` (on the row button) and a stable `pay-option-{assetSymbol}-{networkName}` id — lowercased, whitespace → `-` (e.g. `pay-option-usdt-polygon`) — so a flow can pick a specific asset+network when the same token appears on multiple networks. The stable id is exposed via a non-interactive native `MaestroAccessibilityMarker` overlay (`PayOptionItem.swift`); the tap falls through to the row button beneath. The `pay-review-token-{networkName}` id and the row's copyable accessibility label are both **lowercased** so the shared `pay_multiple_options_nokyc` flow (which copies the row label and asserts `pay-review-token-${copiedText}`) stays consistent with the hardcoded lowercase ids used by `pay_usdt_polygon`.

#### USDT-on-Polygon Permit2 flow (`pay_usdt_polygon`)

USDT on Polygon is a plain ERC-20, so WC Pay uses the Permit2 path: the wallet sends an on-chain `approve` then the payment tx. While setting a token up for the first time (allowance 0), `PayConfirmingView` shows the setup note under id `pay-loading-setup-note` (the flow observes it best-effort). CI resets the Permit2 allowance back to 0 after the suite (`Reset USDT Permit2 allowance (Polygon)` step in `ci_e2e_pay_tests.yml`, via the shared `WalletConnect/actions/maestro/permit2-reset` action) so each run re-exercises `approve`; `e2e_balance_check.yml` monitors USDT + POL (gas) on Polygon. The test wallet must hold USDT **and** a little POL on Polygon.

> The `pay-tests` and `permit2-reset` actions are temporarily pinned to the [actions#97](https://github.com/WalletConnect/actions/pull/97) head SHA (`d07c1f8a…`). Re-pin both to the master merge commit once #97 lands.
