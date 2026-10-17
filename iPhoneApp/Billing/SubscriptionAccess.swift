import Foundation

/// Product IDs are supplied explicitly. An unconfigured build never contacts the store.
struct SubscriptionCatalog: Sendable, Equatable {
    let productIDs: Set<String>
    static let unconfigured = Self(productIDs: [])
}

struct SubscriptionGrant: Sendable, Equatable {
    let productID: String
    let expiresAt: Date
    let inGracePeriod: Bool
    var transactionID: UInt64?

    func isValid(at date: Date) -> Bool { expiresAt > date }
}

enum SubscriptionAccessIssue: Sendable, Equatable {
    case notChecked, verificationFailed, statusUnavailable
}

enum SubscriptionAccess: Sendable, Equatable {
    case unconfigured
    case unknown(SubscriptionAccessIssue)
    case inactive
    case active(SubscriptionGrant)

    func grant(at date: Date) -> SubscriptionGrant? {
        guard case .active(let grant) = self, grant.isValid(at: date) else { return nil }
        return grant
    }
}

/// Only the StoreKit verification boundary creates evidence in production.
/// Keeping resolution pure lets tests exercise uncertainty without forging transactions.
struct SubscriptionEvidence: Sendable {
    let productID: String
    let verified: Bool
    let expiresAt: Date?
    var revoked = false
    var upgraded = false
    var graceExpiresAt: Date?
    var transactionID: UInt64?

    static func resolve(
        _ evidence: [Self], catalog: SubscriptionCatalog, at date: Date,
        statusUnavailable: Bool = false
    ) -> SubscriptionAccess {
        guard !catalog.productIDs.isEmpty else { return .unconfigured }
        var grants: [SubscriptionGrant] = []
        var uncertain = false
        for item in evidence where catalog.productIDs.contains(item.productID) {
            guard item.verified else { uncertain = true; continue }
            guard !item.revoked && !item.upgraded else { continue }
            if let expiry = item.graceExpiresAt {
                if expiry > date {
                    grants.append(.init(productID: item.productID, expiresAt: expiry, inGracePeriod: true,
                        transactionID: item.transactionID))
                }
            } else if let expiry = item.expiresAt, expiry > date {
                grants.append(.init(productID: item.productID, expiresAt: expiry, inGracePeriod: false,
                    transactionID: item.transactionID))
            }
        }
        if let grant = grants.max(by: { $0.expiresAt < $1.expiresAt }) { return .active(grant) }
        if uncertain { return .unknown(.verificationFailed) }
        if statusUnavailable { return .unknown(.statusUnavailable) }
        return .inactive
    }
}

struct SubscriptionPeriod: Sendable, Equatable {
    enum Unit: Sendable { case day, week, month, year }
    let value: Int
    let unit: Unit
}

struct SubscriptionPlan: Sendable, Identifiable, Equatable {
    struct Trial: Sendable, Equatable {
        let period: SubscriptionPeriod
        let numberOfPeriods: Int
    }
    let id: String
    let name: String
    let displayPrice: String
    let period: SubscriptionPeriod
    /// Present only when StoreKit confirms eligibility for this actual free-trial offer.
    let eligibleTrial: Trial?
}

enum SubscriptionActionResult: Sendable, Equatable {
    case purchased, cancelled, pending, unverified, failed, unavailable, busy
    case restored, nothingToRestore
}
