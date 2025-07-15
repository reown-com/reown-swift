
import Foundation

public enum SessionApproveExecutionTraceEvents: String, TraceEventItem {
    case approvingSessionProposal = "approving_session_proposal"
    case sessionNamespacesValidationStarted = "session_namespaces_validation_started"
    case sessionNamespacesValidationSuccess = "session_namespaces_validation_success"
    case settleRequestSent = "settle_request_sent"
    case approvSessionSuccess = "approve_session_success"

    public var description: String {
        return self.rawValue
    }
}

public enum ApproveSessionTraceErrorEvents: String, ErrorEvent {
    case sessionNamespacesValidationFailure = "session_namespaces_validation_failure"
    case proposalNotFound = "proposal_not_found"
    case proposalExpired = "proposal_expired"
    case networkNotConnected = "network_not_connected"
    case agreementMissingOrInvalid = "agreement_missing_or_invalid"
    case relayNotFound = "relay_not_found"
    case approveSessionFailure = "approve_session_failure"

    public var description: String {
        return self.rawValue
    }
}
