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
