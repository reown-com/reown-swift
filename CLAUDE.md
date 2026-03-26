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
