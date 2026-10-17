import Foundation
import PrototypeSupport
import StoreKit
import StoreKitTest
import Testing
@testable import TeleprompterPhone

// Apple's local StoreKit daemon is shared by this test process, so these sessions must be serial.
// The catalog is a test-bundle resource. Neither test prices nor products ship in the app bundle.
@Suite(.serialized) struct SubscriptionStoreKitTests {
    private let monthly = "local.teleprompter.pro.monthly"
    private let annual = "local.teleprompter.pro.annual"
    private var catalog: SubscriptionCatalog { .init(productIDs: [monthly, annual]) }

    @Test @MainActor func purchaseEventsDeduplicateApprovalAndKeepRestoreSeparateFromRenewal() async throws {
        let session = try session(), root = FileManager.default.temporaryDirectory.appendingPathComponent("p5d-purchase-\(UUID())")
        defer { session.clearTransactions(); try? FileManager.default.removeItem(at: root) }
        let events = LocalEventRecorder(root: root)
        let store = SubscriptionStore(catalog: catalog, events: events)
        defer { store.stop() }
        await store.start()
        let presentation = UUID()
        store.recordPaywall(id: presentation); store.recordPaywall(id: presentation)
        session.askToBuyEnabled = true
        async let first = store.purchase(monthly)
        async let second = store.purchase(monthly)
        let outcomes = await [first, second]
        #expect(outcomes.filter { $0 == .pending }.count == 1 && outcomes.filter { $0 == .busy }.count == 1)
        let pending = try #require(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        try await eventually { store.lastResult == .purchased && store.hasPro }
        await store.refreshAccess(); await store.refreshAccess(); await events.flush()
        var rows = await events.journal.snapshot()
        #expect(rows.filter { $0.payload.name == "paywall_viewed" }.count == 1)
        let purchased = rows.filter { $0.payload.name == "purchase_result" }
        #expect(purchased.count == 2 && purchased[0].operationID == purchased[1].operationID)
        #expect(purchased.contains { if case .purchaseResult(action: .purchase, outcome: .verified, plan: .monthly, trial: _, store: .xcode) = $0.payload { true } else { false } })
        #expect(await store.restore() == .restored)
        await events.flush()
        let count = await events.journal.snapshot().count
        try session.forceRenewalOfSubscription(productIdentifier: monthly)
        await store.refreshAccess(); await events.flush()
        rows = await events.journal.snapshot()
        #expect(rows.count == count)
        #expect(rows.contains { if case .purchaseResult(action: .restore, outcome: .restored, plan: .monthly, trial: .notEstablished, store: .unknown) = $0.payload { true } else { false } })
        store.stop()
        let reopenedEvents = LocalEventRecorder(root: root)
        let reopened = SubscriptionStore(catalog: catalog, events: reopenedEvents)
        defer { reopened.stop() }
        await reopened.start(); await reopenedEvents.flush()
        let reopenedRows = await reopenedEvents.journal.snapshot()
        #expect(reopened.hasPro && reopenedRows == rows)
    }

    @Test @MainActor func cancelledUnverifiedFailedAndEmptyRestoreEventsNeverClaimPurchaseSuccess() async throws {
        let session = try session(), root = FileManager.default.temporaryDirectory.appendingPathComponent("p5d-purchase-errors-\(UUID())")
        defer { session.clearTransactions(); try? FileManager.default.removeItem(at: root) }
        let events = LocalEventRecorder(root: root)
        let cancelled = SubscriptionStore(catalog: catalog, purchase: { _ in .userCancelled }, events: events)
        let failed = SubscriptionStore(catalog: catalog, purchase: { _ in throw StoreKitError.notAvailableInStorefront }, events: events)
        defer { cancelled.stop(); failed.stop() }
        await cancelled.start(); await failed.start()
        #expect(await cancelled.purchase(monthly) == .cancelled)
        #expect(await failed.purchase(monthly) == .failed)
        #expect(await cancelled.restore() == .nothingToRestore)
        let native = SubscriptionStore(catalog: catalog, events: events)
        defer { native.stop() }
        await native.start()
        try await session.setSimulatedError(.verification(.invalidSignature), forAPI: StoreKitVerificationAPI())
        #expect(await native.purchase(monthly) == .unverified)
        await events.flush()
        let rows = await events.journal.snapshot()
        #expect(rows.count == 4)
        #expect(rows.allSatisfy { if case .purchaseResult(_, let outcome, _, .notEstablished, .unknown) = $0.payload { outcome == .cancelled || outcome == .failed || outcome == .none || outcome == .unverified } else { false } })
        #expect(!cancelled.hasPro && !failed.hasPro)
    }

    @Test @MainActor func nativeCatalogPurchaseAndRestoreUseVerifiedStoreKitState() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let store = SubscriptionStore(catalog: catalog)
        defer { store.stop() }
        await store.start()
        #expect(store.access == .inactive && store.plans.count == 2 && !store.catalogUnavailable)
        let native = try #require(try await Product.products(for: [monthly]).first)
        let plan = try #require(store.plans.first { $0.id == monthly })
        #expect(plan.displayPrice == native.displayPrice)
        #expect(plan.period == .init(value: 1, unit: .month))
        // The local daemon can retain offer history across sessions; compare actual eligibility.
        let eligible = await native.subscription?.isEligibleForIntroOffer == true
        #expect(plan.eligibleTrial == (eligible ? .init(period: .init(value: 1, unit: .week), numberOfPeriods: 1) : nil))
        #expect(await store.purchase(monthly) == .purchased)
        #expect(store.hasPro && store.access.grant(at: Date())?.productID == monthly)
        #expect(store.plans.allSatisfy { $0.eligibleTrial == nil })
        #expect(await store.restore() == .restored)
    }

    @Test @MainActor func renewalExpiryAndRefundArriveThroughSignedState() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let store = SubscriptionStore(catalog: catalog)
        defer { store.stop() }
        await store.start()
        #expect(await store.purchase(monthly) == .purchased)
        let initial = try #require(store.access.grant(at: Date()))
        try session.forceRenewalOfSubscription(productIdentifier: monthly)
        try await eventually("Renewal transaction replaces the original grant") {
            store.access.grant(at: Date()).map { $0.transactionID != initial.transactionID } == true
        }
        let renewedID = try #require(store.access.grant(at: Date())?.transactionID)
        // Expiry with auto-renew enabled immediately grants the next paid period in StoreKitTest.
        // Disable renewal first to test an actual subscription ending rather than a successful renewal.
        try session.disableAutoRenewForTransaction(identifier: UInt(renewedID))
        try session.expireSubscription(productIdentifier: monthly)
        try await eventually("Forced expiry removes access") { await store.refreshAccess(); return store.access == .inactive }
        let second = try await session.buyProduct(identifier: annual)
        try await eventually("A new annual purchase grants access") { store.hasPro }
        try session.refundTransaction(identifier: UInt(second.id))
        try await eventually("Refund removes access") { await store.refreshAccess(); return store.access == .inactive }
    }

    @Test @MainActor func pendingDoesNotUnlockAndApprovalUpdatesWithoutAnotherPurchase() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        session.askToBuyEnabled = true
        let store = SubscriptionStore(catalog: catalog)
        defer { store.stop() }
        await store.start()
        #expect(await store.purchase(monthly) == .pending)
        #expect(!store.hasPro)
        let transaction = try #require(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        try await eventually { store.hasPro && store.lastResult == .purchased }
        #expect(session.allTransactions().count == 1)
    }

    @Test @MainActor func cancelledResultAndCancelledErrorDoNotGrantAccess() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        // Xcode 27's simulated .userCancelled returns an unmapped ASDServerErrorDomain/907.
        // Exercise the documented result/error at the narrow purchase boundary instead of
        // teaching production code a private error code. Native sheet cancellation is a P5B UI gate.
        let cancelled = SubscriptionStore(catalog: catalog, purchase: { _ in .userCancelled })
        let thrown = SubscriptionStore(catalog: catalog, purchase: { _ in throw StoreKitError.userCancelled })
        defer { cancelled.stop(); thrown.stop() }
        await cancelled.start(); await thrown.start()
        #expect(await cancelled.purchase(monthly) == .cancelled)
        #expect(await thrown.purchase(monthly) == .cancelled)
        #expect(!cancelled.hasPro && !thrown.hasPro)
        #expect(session.allTransactions().isEmpty)
    }

    @Test @MainActor func nativeStoreFailureDoesNotGrantAccess() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let store = SubscriptionStore(catalog: catalog)
        defer { store.stop() }
        await store.start()
        try await session.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: StoreKitPurchaseAPI())
        #expect(await store.purchase(monthly) == .failed)
        #expect(!store.hasPro)
    }

    @Test @MainActor func unavailableCatalogAndRestoreFailurePreserveSignedLocalAccessAcrossModelRestart() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let first = SubscriptionStore(catalog: catalog)
        await first.start()
        #expect(await first.purchase(monthly) == .purchased)
        first.stop()
        // Simulate catalog and authentication failures independently. Entitlement rehydration is local.
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: StoreKitLoadProductsAPI())
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: StoreKitAppStoreSyncAPI())
        let restarted = SubscriptionStore(catalog: catalog)
        defer { restarted.stop() }
        await restarted.start()
        #expect(restarted.hasPro && restarted.catalogUnavailable && restarted.plans.isEmpty)
        #expect(await restarted.restore() == .failed)
        #expect(restarted.hasPro)
    }

    @Test @MainActor func unverifiedPurchaseCannotUnlockAndRestoreReportsNoneTruthfully() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let store = SubscriptionStore(catalog: catalog)
        defer { store.stop() }
        await store.start()
        #expect(await store.restore() == .nothingToRestore)
        try await session.setSimulatedError(.verification(.invalidSignature), forAPI: StoreKitVerificationAPI())
        #expect(await store.purchase(monthly) == .unverified)
        #expect(!store.hasPro)
        await store.refreshAccess()
        #expect(store.access == .unknown(.verificationFailed))
    }

    @Test @MainActor func duplicatePurchaseRequestsProduceOnlyOneTransaction() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let store = SubscriptionStore(catalog: catalog)
        defer { store.stop() }
        await store.start()
        async let first = store.purchase(monthly)
        async let second = store.purchase(monthly)
        let outcomes = await [first, second]
        #expect(outcomes.filter { $0 == .purchased }.count == 1)
        #expect(outcomes.filter { $0 == .busy }.count == 1)
        #expect(session.allTransactions().count == 1 && store.hasPro)
    }

    @Test @MainActor func nativeBillingGraceUsesVerifiedRenewalDeadline() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        session.billingGracePeriodIsEnabled = true
        session.shouldEnterBillingRetryOnRenewal = true
        session.timeRate = .oneRenewalEveryTenSeconds
        let store = SubscriptionStore(catalog: catalog)
        defer { store.stop() }
        await store.start()
        #expect(await store.purchase(monthly) == .purchased)
        try await eventually("Billing grace grants access through its verified deadline") {
            await store.refreshAccess()
            return store.access.grant(at: Date())?.inGracePeriod == true
        }
        let status = try #require(try await Product.SubscriptionInfo.status(for: "5EA34CB1").first { $0.state == .inGracePeriod })
        guard case .verified(let renewal) = status.renewalInfo else {
            Issue.record("Expected verified renewal info for local grace"); return
        }
        #expect(store.access.grant(at: Date())?.expiresAt == renewal.gracePeriodExpirationDate)
    }

    // P5C shares this serialized suite because Apple's local StoreKit daemon is process-wide.
    // Capture is a test controller; the saved media is a real synthetic MOV, not camera evidence.
    @Test @MainActor func purchaseExpiryAndRefundCannotStopAnAcceptedTakeOrBlockTheNextOne() async throws {
        let session = try session()
        defer { session.resetToDefaultState(); session.clearTransactions() }
        let billing = SubscriptionStore(catalog: catalog)
        defer { billing.stop() }
        await billing.start()
        #expect(billing.access == .inactive)
        let root = policyRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (recorder, capture) = await policyRecorder(root)
        let request = try await beginPolicyTake(recorder, capture)

        #expect(await billing.purchase(monthly) == .purchased)
        let grant = try #require(billing.access.grant(at: Date()))
        await expectPolicyTakeStillRecording(recorder, capture, request)
        try session.disableAutoRenewForTransaction(identifier: UInt(try #require(grant.transactionID)))
        try session.expireSubscription(productIdentifier: monthly)
        try await eventually("Expiry during a take") { await billing.refreshAccess(); return billing.access == .inactive }
        await expectPolicyTakeStillRecording(recorder, capture, request)

        let annualTransaction = try await session.buyProduct(identifier: annual)
        try await eventually { billing.hasPro }
        try session.refundTransaction(identifier: UInt(annualTransaction.id))
        try await eventually("Refund during the same take") { await billing.refreshAccess(); return billing.access == .inactive }
        await expectPolicyTakeStillRecording(recorder, capture, request)
        _ = try await finishPolicyTake(recorder, request)
        #expect(recorder.canRecord)
        let next = try await beginPolicyTake(recorder, capture)
        _ = try await finishPolicyTake(recorder, next)
        #expect(recorder.takes.count == 2 && recorder.takes.allSatisfy(\.isPlayable))
        #expect(await capture.requests.count == 2)
    }

    @Test @MainActor func pendingApprovalAndStoreFailuresKeepCaptureEditsAndExportAvailable() async throws {
        let session = try session()
        defer { session.resetToDefaultState(); session.clearTransactions() }
        session.askToBuyEnabled = true
        let billing = SubscriptionStore(catalog: catalog)
        defer { billing.stop() }
        await billing.start()
        #expect(await billing.purchase(monthly) == .pending)
        #expect(!billing.hasPro)
        let root = policyRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (recorder, capture) = await policyRecorder(root)
        let request = try await beginPolicyTake(recorder, capture)
        let pending = try #require(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        try await eventually { billing.hasPro }
        await expectPolicyTakeStillRecording(recorder, capture, request)
        try session.refundTransaction(identifier: pending.identifier)
        try await eventually { await billing.refreshAccess(); return billing.access == .inactive }
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: StoreKitLoadProductsAPI())
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: StoreKitAppStoreSyncAPI())
        // Refund/status notifications may already own a product refresh. Wait for a
        // completed failing request instead of treating a coalesced early return as completion.
        try await eventually("Catalog failure after the refund refresh") {
            await billing.loadProducts()
            return !billing.loadingProducts && billing.catalogUnavailable
        }
        #expect(await billing.restore() == .failed && !billing.hasPro)
        await expectPolicyTakeStillRecording(recorder, capture, request)
        let take = try await finishPolicyTake(recorder, request)
        let original = try Data(contentsOf: request.url)
        await recorder.openTake(take)
        let editing = try #require(await recorder.beginEditingTake(id: take.id))
        let editor = VideoEditorModel(session: editing, title: "P5C policy sample", store: recorder.edits, media: recorder.media)
        await editor.load(); editor.setStart(0.3); editor.setEnd(2.7)
        var crop = try #require(editor.cropSelection()); crop.select(.portrait)
        editor.applyCrop(crop)
        let saved = try #require(await editor.exportSnapshot())
        await recorder.mp4Exports.open(edit: saved, source: request.url)
        try await eventually("Export without a subscription after StoreKit failures") {
            recorder.mp4Exports.phase == .ready && !recorder.mp4Exports.isBusy
        }
        #expect(!billing.hasPro && recorder.mp4Exports.outputURL != nil)
        recorder.mp4Exports.delivery.start(.files)
        try await eventually { recorder.mp4Exports.delivery.presentation != nil }
        let presentation = try #require(recorder.mp4Exports.delivery.presentation)
        recorder.mp4Exports.delivery.completePresentation(id: presentation.id, completed: false)
        try await eventually { !recorder.mp4Exports.delivery.isBusy }
        await recorder.mp4Exports.leave()
        editor.close(); recorder.endEditingTake(editing); recorder.stopPlayback(takeID: take.id)
        await recorder.playbackReleaseTask?.value
        #expect(try Data(contentsOf: request.url) == original)
        #expect(try await recorder.edits.load(takeID: take.id, source: saved.source)?.recipe == saved.recipe)
    }

    @Test(arguments: PolicyAccessFixture.allCases) @MainActor
    func uncertainUnconfiguredAndGraceAccessDoNotGateNewRecordings(fixture: PolicyAccessFixture) async throws {
        let session = try session()
        defer { session.resetToDefaultState(); session.clearTransactions() }
        let expected = fixture.access
        let billing = SubscriptionStore(catalog: fixture == .unconfigured ? .unconfigured : catalog,
            entitlements: { _ in expected })
        defer { billing.stop() }
        await billing.start()
        #expect(billing.access == expected)
        let root = policyRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (recorder, capture) = await policyRecorder(root)
        let request = try await beginPolicyTake(recorder, capture)
        _ = try await finishPolicyTake(recorder, request)
        #expect(recorder.canRecord && recorder.takes.count == 1)
    }

    private func policyRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("p5c-policy-\(UUID())", isDirectory: true)
    }

    @MainActor private func policyRecorder(_ root: URL) async -> (PrototypeModel, TestCapture) {
        let capture = TestCapture()
        let recorder = PrototypeModel(root: root, capture: capture,
            requestPermissions: { .init(camera: .authorized, microphone: .authorized) },
            availableCapacity: { _ in CaptureStoragePolicy.requiredFreeBytes }, countdownTick: {})
        await recorder.initialize(); await recorder.enterCamera()
        return (recorder, capture)
    }

    @MainActor private func beginPolicyTake(_ recorder: PrototypeModel, _ capture: TestCapture) async throws -> TestCapture.Request {
        try #require(recorder.canRecord)
        recorder.start(); await recorder.countdownTask?.value
        let request = try #require(await capture.requests.last)
        await recorder.handle(.started(request.id))
        await expectPolicyTakeStillRecording(recorder, capture, request)
        return request
    }

    @MainActor private func expectPolicyTakeStillRecording(
        _ recorder: PrototypeModel, _ capture: TestCapture, _ request: TestCapture.Request
    ) async {
        #expect(recorder.phase == .recording && recorder.playing)
        #expect(await capture.requests.last?.id == request.id)
        #expect(await !capture.stops.contains(request.id))
    }

    @MainActor private func finishPolicyTake(_ recorder: PrototypeModel, _ request: TestCapture.Request) async throws -> PrototypeTake {
        recorder.stop()
        try await SampleMovie().make(at: request.url)
        await recorder.handle(.finished(request.id, request.url, true, nil))
        let take = try #require(recorder.takes.first { $0.id == request.id })
        #expect(take.isPlayable && recorder.phase == .idle)
        return take
    }

    private func session() throws -> SKTestSession {
        try #require(ProcessInfo.processInfo.environment["TELEPROMPTER_LOCAL_STOREKIT_TEST"] == "1",
            "Use the TeleprompterPhone-P5 scheme so purchases stay in Xcode's local StoreKit environment")
        let url = try #require(Bundle(for: StoreKitTestBundleMarker.self).url(forResource: "TeleprompterLocal", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.timeRate = .realTime
        return session
    }

    @MainActor private func eventually(_ message: String = "StoreKit update", _ condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(12))
        while ContinuousClock.now < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        Issue.record("\(message): StoreKit did not reach the expected signed state within 12 seconds")
        throw StoreKitWaitFailure()
    }
}

private final class StoreKitTestBundleMarker: NSObject {}
private struct StoreKitWaitFailure: Error {}

enum PolicyAccessFixture: CaseIterable, Sendable {
    case unconfigured, unavailable, unverified, grace
    var access: SubscriptionAccess {
        switch self {
        case .unconfigured: .unconfigured
        case .unavailable: .unknown(.statusUnavailable)
        case .unverified: .unknown(.verificationFailed)
        case .grace: .active(.init(productID: "local.teleprompter.pro.monthly",
            expiresAt: Date().addingTimeInterval(3600), inGracePeriod: true))
        }
    }
}
