import XCTest
@testable import ReownWalletKit

final class PaymentLinkDetectorTests: XCTestCase {

    // MARK: - Payment Links (should match)

    func testPayWalletConnectComUrl() {
        let url = "https://pay.walletconnect.com/?pid=pay_123"
        XCTAssertTrue(PaymentLinkDetector.isPaymentLink(url))
    }

    func testPayWalletConnectComWithPathPaymentId() {
        let url = "https://pay.walletconnect.com/pay_123"
        XCTAssertTrue(PaymentLinkDetector.isPaymentLink(url))
    }

    func testStagingPayWalletConnectComUrl() {
        let url = "https://staging.pay.walletconnect.com/?pid=pay_123"
        XCTAssertTrue(PaymentLinkDetector.isPaymentLink(url))
    }

    func testPayWctMeUrl() {
        let url = "https://pay.wct.me/123"
        XCTAssertTrue(PaymentLinkDetector.isPaymentLink(url))
    }

    func testWcUriWithPayParam() {
        let uri = "wc:abc@2?pay=https%3A%2F%2Fpay.walletconnect.com%2F%3Fpid%3Dpay_123"
        XCTAssertTrue(PaymentLinkDetector.isPaymentLink(uri))
    }

    func testFullyEncodedWcUri() {
        let uri = "wc%3Aabc%402%3Fpay%3Dhttps%253A%252F%252Fpay.walletconnect.com%252F"
        XCTAssertTrue(PaymentLinkDetector.isPaymentLink(uri))
    }

    func testBarePaymentId() {
        let paymentId = "pay_123"
        XCTAssertTrue(PaymentLinkDetector.isPaymentLink(paymentId))
    }

    func testEncodedBarePaymentId() {
        let paymentId = "pay%5F123"
        XCTAssertTrue(PaymentLinkDetector.isPaymentLink(paymentId))
    }

    func testEncodedPayDot() {
        let url = "https%3A%2F%2Fpay%2ewalletconnect.com"
        XCTAssertTrue(PaymentLinkDetector.isPaymentLink(url))
    }

    func testEncodedPayEquals() {
        let uri = "wc:abc@2%3Fpay%3Dhttps://..."
        XCTAssertTrue(PaymentLinkDetector.isPaymentLink(uri))
    }

    // MARK: - Non-Payment Links (should NOT match)

    func testRegularCheckoutUrl() {
        let url = "https://example.com/checkout"
        XCTAssertFalse(PaymentLinkDetector.isPaymentLink(url))
    }

    func testRegularWcUri() {
        let uri = "wc:abc123@2?relay-protocol=irn&symKey=xyz"
        XCTAssertFalse(PaymentLinkDetector.isPaymentLink(uri))
    }

    func testRandomPaymentUrl() {
        let url = "https://payments.example.com/process"
        XCTAssertFalse(PaymentLinkDetector.isPaymentLink(url))
    }

    func testEmptyString() {
        XCTAssertFalse(PaymentLinkDetector.isPaymentLink(""))
    }

    func testRandomId() {
        let id = "abc_123"
        XCTAssertFalse(PaymentLinkDetector.isPaymentLink(id))
    }

    // MARK: - Case Insensitivity

    func testUppercasePay() {
        let url = "https://PAY.walletconnect.com/?pid=pay_123"
        XCTAssertTrue(PaymentLinkDetector.isPaymentLink(url))
    }

    func testMixedCasePay() {
        let uri = "wc:abc@2?PAY=https://..."
        XCTAssertTrue(PaymentLinkDetector.isPaymentLink(uri))
    }

    func testUppercasePaymentId() {
        let paymentId = "PAY_ABC"
        XCTAssertTrue(PaymentLinkDetector.isPaymentLink(paymentId))
    }
}
