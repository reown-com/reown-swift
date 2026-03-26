import Foundation
import Combine

enum ImportChain: String, CaseIterable, Identifiable {
    case evm = "EVM"
    case solana = "Solana"
    case sui = "Sui"
    case ton = "TON"
    case tron = "Tron"
    case stacks = "Stacks"

    var id: String { rawValue }

    var placeholder: String {
        switch self {
        case .evm: return "Enter mnemonic or private key (0x...)"
        case .solana: return "Enter Base58 private key"
        case .sui: return "Enter mnemonic phrase (12-24 words)"
        case .ton: return "Enter base64 Ed25519 seed (32 bytes)"
        case .tron: return "Enter private key (64 hex)"
        case .stacks: return "Enter mnemonic phrase"
        }
    }
}

final class ImportWalletPresenter: ObservableObject {

    @Published var selectedChain: ImportChain = .evm
    @Published var input: String = ""
    @Published var isImporting: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showSuccess: Bool = false

    private let walletService: WalletGenerationService

    init(walletService: WalletGenerationService) {
        self.walletService = walletService
    }

    var canImport: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isImporting
    }

    func importWallet() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !trimmed.isEmpty else { return }

        isImporting = true
        errorMessage = nil

        let success: Bool
        switch selectedChain {
        case .evm:
            success = importEVM(trimmed)
        case .solana:
            success = walletService.importSolanaPrivateKey(trimmed)
        case .sui:
            success = walletService.importSuiKeypair(trimmed)
        case .ton:
            success = walletService.importTonPrivateKey(trimmed)
        case .tron:
            success = walletService.importTronPrivateKey(trimmed)
        case .stacks:
            success = walletService.importStacksMnemonic(trimmed)
        }

        isImporting = false

        if success {
            input = ""
            showSuccess = true
            NotificationCenter.default.post(name: .walletImported, object: nil)
        } else {
            errorMessage = "Invalid input for \(selectedChain.rawValue)"
        }
    }

    private func importEVM(_ input: String) -> Bool {
        let words = input.components(separatedBy: " ")
        if [12, 15, 18, 21, 24].contains(words.count) {
            return walletService.importEVMMnemonic(input)
        } else {
            return walletService.importEVMPrivateKey(input)
        }
    }
}
