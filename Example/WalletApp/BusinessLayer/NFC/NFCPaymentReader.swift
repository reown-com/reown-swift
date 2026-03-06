import CoreNFC

/// Reads payment URLs from NFC tags using CoreNFC.
///
/// On iOS, the phone acts as an NFC reader (unlike Android where HCE makes
/// the phone act as a card). The POS terminal presents the payment URL via:
/// - A physical NFC tag attached to the terminal (written by the POS)
/// - NDEF Type 4 Tag emulation via HCE (on POS devices that support it)
///
/// Usage:
/// ```
/// NFCPaymentReader.shared.scan { result in
///     switch result {
///     case .success(let paymentUrl): handlePayment(paymentUrl)
///     case .failure(let error): showError(error)
///     }
/// }
/// ```
final class NFCPaymentReader: NSObject {

    typealias Completion = (Result<String, Error>) -> Void

    static let shared = NFCPaymentReader()

    /// Set to `true` before presenting a payment modal so the next
    /// `onAppear` auto-scan is skipped (avoids NFC sheet over the modal).
    static var suppressAutoScan = false

    private var session: NFCNDEFReaderSession?
    private var completion: Completion?

    /// Starts an NFC scanning session to read a payment URL from an NDEF tag.
    /// Shows the iOS NFC scanning sheet ("Hold your iPhone near...").
    func scan(completion: @escaping Completion) {
        guard NFCNDEFReaderSession.readingAvailable else {
            completion(.failure(NFCPaymentError.notAvailable))
            return
        }

        self.completion = completion
        session = NFCNDEFReaderSession(
            delegate: self,
            queue: .main,
            invalidateAfterFirstRead: true
        )
        session?.alertMessage = "Ready to Pay"
        session?.begin()
    }

    /// Whether NFC reading is available on this device.
    static var isAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCPaymentReader: NFCNDEFReaderSessionDelegate {

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        // Session became active — scanning
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        for message in messages {
            for record in message.records {
                // Try to extract a URI from the NDEF record
                if let url = record.wellKnownTypeURIPayload() {
                    let urlString = url.absoluteString
                    print("NFC: Payment URL read from tag: \(urlString)")
                    session.alertMessage = "Payment link received!"
                    session.invalidate()
                    completion?(.success(urlString))
                    completion = nil
                    return
                }
            }
        }

        session.invalidate(errorMessage: "No payment link found on this NFC tag.")
        completion?(.failure(NFCPaymentError.noPaymentLink))
        completion = nil
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // User cancelled — don't report as error
        if let nfcError = error as? NFCReaderError,
           nfcError.code == .readerSessionInvalidationErrorFirstNDEFTagRead ||
           nfcError.code == .readerSessionInvalidationErrorUserCanceled {
            if nfcError.code == .readerSessionInvalidationErrorUserCanceled {
                completion?(.failure(NFCPaymentError.cancelled))
                completion = nil
            }
            return
        }

        completion?(.failure(error))
        completion = nil
    }
}

// MARK: - Error

enum NFCPaymentError: LocalizedError {
    case notAvailable
    case noPaymentLink
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "NFC is not available on this device."
        case .noPaymentLink:
            return "No payment link found on the NFC tag."
        case .cancelled:
            return "NFC scan cancelled."
        }
    }
}
