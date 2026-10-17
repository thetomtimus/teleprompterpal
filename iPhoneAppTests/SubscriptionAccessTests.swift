import Foundation
import Testing
@testable import TeleprompterPhone

struct SubscriptionAccessTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let catalog = SubscriptionCatalog(productIDs: ["monthly", "annual"])

    @Test func signedFutureExpiryIsRequiredAndRevocationWins() {
        let future = now.addingTimeInterval(300)
        let valid = SubscriptionEvidence(productID: "monthly", verified: true, expiresAt: future)
        #expect(SubscriptionEvidence.resolve([valid], catalog: catalog, at: now).grant(at: now)?.expiresAt == future)
        for invalid in [
            SubscriptionEvidence(productID: "monthly", verified: true, expiresAt: now),
            SubscriptionEvidence(productID: "monthly", verified: true, expiresAt: nil),
            SubscriptionEvidence(productID: "monthly", verified: true, expiresAt: future, revoked: true),
            SubscriptionEvidence(productID: "monthly", verified: true, expiresAt: future, upgraded: true),
            SubscriptionEvidence(productID: "other", verified: true, expiresAt: future)
        ] {
            #expect(SubscriptionEvidence.resolve([invalid], catalog: catalog, at: now) == .inactive)
        }
    }

    @Test func uncertaintyAndVerifiedEmptyAreDifferent() {
        let unverified = SubscriptionEvidence(productID: "annual", verified: false, expiresAt: now.addingTimeInterval(1000))
        #expect(SubscriptionEvidence.resolve([unverified], catalog: catalog, at: now) == .unknown(.verificationFailed))
        #expect(SubscriptionEvidence.resolve([], catalog: catalog, at: now) == .inactive)
        #expect(SubscriptionEvidence.resolve([], catalog: catalog, at: now, statusUnavailable: true) == .unknown(.statusUnavailable))
        #expect(SubscriptionEvidence.resolve([], catalog: .unconfigured, at: now) == .unconfigured)
    }

    @Test func verifiedGraceHasItsOwnDeadlineAndCannotSurviveRevocation() {
        let deadline = now.addingTimeInterval(30)
        let grace = SubscriptionEvidence(productID: "monthly", verified: true,
            expiresAt: now.addingTimeInterval(-1), graceExpiresAt: deadline)
        let access = SubscriptionEvidence.resolve([grace], catalog: catalog, at: now)
        #expect(access.grant(at: now)?.inGracePeriod == true)
        #expect(access.grant(at: deadline) == nil)
        #expect(SubscriptionEvidence.resolve([grace], catalog: catalog, at: deadline) == .inactive)
        var revoked = grace; revoked.revoked = true
        #expect(SubscriptionEvidence.resolve([revoked], catalog: catalog, at: now) == .inactive)
        let unsigned = SubscriptionEvidence(productID: grace.productID, verified: false,
            expiresAt: grace.expiresAt, graceExpiresAt: deadline)
        #expect(SubscriptionEvidence.resolve([unsigned], catalog: catalog, at: now) == .unknown(.verificationFailed))
        let futureTransaction = SubscriptionEvidence(productID: "monthly", verified: true,
            expiresAt: deadline.addingTimeInterval(300), graceExpiresAt: deadline)
        #expect(SubscriptionEvidence.resolve([futureTransaction], catalog: catalog, at: now).grant(at: now)?.inGracePeriod == true)
        #expect(SubscriptionEvidence.resolve([futureTransaction], catalog: catalog, at: deadline) == .inactive)
    }

    @Test @MainActor func unconfiguredStoreCannotPurchaseOrRestore() async {
        let store = SubscriptionStore()
        await store.start()
        #expect(store.access == .unconfigured && store.plans.isEmpty && !store.hasPro)
        #expect(await store.purchase("anything") == .unavailable)
        #expect(await store.restore() == .unavailable)
    }

    @Test @MainActor func unavailableRecheckPreservesSignedGrantButVerifiedEmptyRemovesIt() async {
        let grant = SubscriptionGrant(productID: "monthly", expiresAt: Date().addingTimeInterval(300), inGracePeriod: false)
        let source = SubscriptionSnapshotSource(.active(grant))
        let store = SubscriptionStore(catalog: catalog, entitlements: { _ in await source.value })
        defer { store.stop() }
        await store.refreshAccess()
        #expect(store.hasPro)
        await source.set(.unknown(.verificationFailed))
        await store.refreshAccess()
        #expect(store.access == .active(grant) && store.hasPro && store.accessIssue == .verificationFailed)
        await source.set(.inactive)
        await store.refreshAccess()
        #expect(store.access == .inactive && !store.hasPro && store.accessIssue == nil)
    }
}

private actor SubscriptionSnapshotSource {
    var value: SubscriptionAccess
    init(_ value: SubscriptionAccess) { self.value = value }
    func set(_ value: SubscriptionAccess) { self.value = value }
}
