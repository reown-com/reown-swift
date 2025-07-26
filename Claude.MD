# Reown Swift - WalletKit & AppKit

## Project Overview
This is the Swift implementation of WalletKit and AppKit for native iOS applications. The project is developed by Reown (formerly WalletConnect) and provides a comprehensive SDK for integrating Web3 wallet connectivity and decentralized app functionality into iOS applications.

## Key Components

### Core Libraries
- **ReownWalletKit**: The main wallet integration SDK
- **ReownAppKit**: Framework for building decentralized apps with wallet connectivity
- **WalletConnectSign**: Handles signing operations and session management
- **WalletConnectPairing**: Manages pairing between wallets and dapps
- **WalletConnectNetworking**: Network layer for WalletConnect protocol
- **WalletConnectRelay**: WebSocket relay implementation
- **WalletConnectVerify**: Verification and attestation services
- **WalletConnectPush**: Push notification support
- **WalletConnectIdentity**: Identity management
- **ReownRouter**: Routing functionality

### Supporting Libraries
- **WalletConnectKMS**: Key Management Service
- **WalletConnectJWT**: JWT token handling
- **WalletConnectUtils**: Common utilities
- **WalletConnectSigner**: Cryptographic signing operations
- **HTTPClient**: HTTP networking client
- **JSONRPC**: JSON-RPC protocol implementation
- **Database**: SQLite database wrapper
- **Events**: Event tracking and analytics
- **Commons**: Common types and extensions

### UI Components
- **ReownAppKitUI**: UI components for AppKit
- **ReownAppKitBackport**: Backward compatibility layer for older iOS versions

## Technical Details

### Platform Requirements
- iOS 13.0+
- macOS 11.0+
- tvOS 13.0+
- Swift 5.5+
- Xcode 13+

### Dependencies
- QRCode (14.3.1+) - QR code generation
- CoinbaseWalletSDK (1.1.0+) - Coinbase wallet integration
- Yttrium (0.9.7) - External dependency for cryptographic operations

### Installation
The project supports installation via:
- Swift Package Manager (SPM)
- CocoaPods

### Architecture
The project follows a modular architecture with clear separation of concerns:
- Networking layer handles all communication
- Sign/Pairing modules manage the WalletConnect protocol
- UI components are separated into their own modules
- Each module has its own privacy manifest (PrivacyInfo.xcprivacy)

## Project Structure
```
/Users/alexminator/conductor/repo/appkit/bandung/
├── Sources/              # Main source code
│   ├── ReownWalletKit/   # Main wallet SDK
│   ├── ReownAppKit/      # App development kit
│   ├── WalletConnect*/   # Various WalletConnect modules
│   └── ...
├── Tests/                # Unit and integration tests
├── Example/              # Example applications
│   ├── AppKitLab/        # AppKit demo app
│   ├── DApp/             # Sample dApp
│   └── WalletApp/        # Sample wallet app
├── Package.swift         # SPM package definition
├── reown-swift.podspec   # CocoaPods specification
└── LICENSE               # Apache 2.0 license
```

## Version
Current version: 1.6.5

## License
Apache License 2.0

## Repository Information
- GitHub: https://github.com/reown-com/reown-swift
- Current branch: conductor/bandung
- Main branch: develop

## Notable Features
- Full WalletConnect v2.0 protocol support
- Coinbase Wallet SDK integration
- Push notifications support
- Identity and verification services
- Comprehensive UI components
- Event tracking and analytics
- Support for multiple blockchain networks
- Chain abstraction capabilities

## Development Notes
- The project uses git for version control
- It includes comprehensive test coverage with unit and integration tests
- CI/CD is configured with GitHub Actions
- The project includes example apps for testing and demonstration
- Uses CocoaPods and Swift Package Manager for dependency management