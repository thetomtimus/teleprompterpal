import Foundation
import Observation
import StoreKit
import PrototypeSupport

/// App-owned observable state. StoreKit supplies signed access; no hasPro flag is persisted.
/// No feature gating is attached here: commercial policy remains a separate product decision.
@MainActor @Observable final class SubscriptionStore {
    private(set) var access: SubscriptionAccess = .unknown(.notChecked)
    private(set) var accessIssue: SubscriptionAccessIssue?
    private(set) var plans: [SubscriptionPlan] = []
    private(set) var catalogUnavailable = false
    private(set) var loadingProducts = false
    private(set) var actionInProgress = false
    private(set) var lastResult: SubscriptionActionResult?

    @ObservationIgnored private let catalog: SubscriptionCatalog
    @ObservationIgnored private let purchaseProduct: @MainActor @Sendable (Product) async throws -> Product.PurchaseResult
    @ObservationIgnored private let readEntitlements: @Sendable (SubscriptionCatalog) async -> SubscriptionAccess
    @ObservationIgnored private var products: [String: Product] = [:]
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var statusTask: Task<Void, Never>?
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var refreshAgain = false
    @ObservationIgnored private var refreshGeneration = 0
    @ObservationIgnored private let events: LocalEventRecorder?
    @ObservationIgnored private var pendingPurchase: (id: UUID, productID: String, plan: LocalEventPayload.Plan)?

    init(catalog: SubscriptionCatalog = .unconfigured,
        purchase: @escaping @MainActor @Sendable (Product) async throws -> Product.PurchaseResult = { try await $0.purchase() },
        entitlements: @escaping @Sendable (SubscriptionCatalog) async -> SubscriptionAccess = { await SubscriptionStore.readAccess(catalog: $0) },
        events: LocalEventRecorder? = nil
    ) {
        self.catalog = catalog
        purchaseProduct = purchase
        readEntitlements = entitlements
        self.events = events
        if catalog.productIDs.isEmpty { access = .unconfigured }
    }

    deinit { updatesTask?.cancel(); statusTask?.cancel(); expiryTask?.cancel(); refreshTask?.cancel() }

    var hasPro: Bool { access.grant(at: Date()) != nil }
    var isConfigured: Bool { !catalog.productIDs.isEmpty }
    var eventAccess: LocalEventPayload.Access {
        switch access {
        case .unconfigured: .unconfigured
        case .unknown: .unknown
        case .inactive: .inactive
        case .active(let grant): grant.isValid(at: Date()) ? (grant.inGracePeriod ? .grace : .verified) : .unknown
        }
    }

    func recordPaywall(id: UUID) {
        guard !loadingProducts, !isConfigured || !plans.isEmpty || catalogUnavailable else { return }
        events?.emit(.paywallViewed(catalog: !isConfigured ? .unconfigured : catalogUnavailable ? .unavailable : .available,
            offers: Array(plans.prefix(16)).map { .init(plan: eventPlan($0.id), eligibleTrial: $0.eligibleTrial != nil) }), operationID: id)
    }

    private func eventPlan(_ productID: String?) -> LocalEventPayload.Plan {
        guard let productID else { return .unspecified }
        guard let plan = plans.first(where: { $0.id == productID }) else { return .other }
        return plan.period.unit == .month && plan.period.value == 1 ? .monthly
            : plan.period.unit == .year && plan.period.value == 1 ? .annual : .other
    }

    /// Launch/foreground refresh uses local StoreKit entitlements, never AppStore.sync().
    func start() async {
        guard !catalog.productIDs.isEmpty else { return }
        if updatesTask == nil {
            updatesTask = Task { @concurrent [weak self] in
                for await update in Transaction.updates {
                    guard !Task.isCancelled else { break }
                    await self?.handle(update)
                }
            }
            statusTask = Task { @concurrent [weak self, catalog] in
                for await status in Product.SubscriptionInfo.Status.updates {
                    guard !Task.isCancelled else { break }
                    let transaction = status.transaction.unsafePayloadValue
                    if catalog.productIDs.contains(transaction.productID) { await self?.refreshAccess() }
                }
            }
        }
        await refreshAccess()
        await loadProducts()
    }

    func stop() {
        updatesTask?.cancel(); updatesTask = nil
        statusTask?.cancel(); statusTask = nil
        expiryTask?.cancel(); expiryTask = nil
        refreshTask?.cancel(); refreshTask = nil
        refreshAgain = false
        refreshGeneration += 1
    }

    func refreshAccess() async {
        guard !catalog.productIDs.isEmpty else { apply(.unconfigured); return }
        // A purchase and its status/transaction notifications can refresh concurrently.
        // Every caller waits for the whole drain, including any recheck requested in flight.
        // Merely dropping superseded results could report a valid purchase as unavailable.
        refreshAgain = true
        if let refreshTask { await refreshTask.value; return }
        refreshGeneration += 1
        let generation = refreshGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            await self.drainRefresh(generation: generation)
        }
        refreshTask = task
        await task.value
    }

    private func drainRefresh(generation: Int) async {
        while refreshAgain && generation == refreshGeneration && !Task.isCancelled {
            refreshAgain = false
            let snapshot = await readEntitlements(catalog)
            guard generation == refreshGeneration, !Task.isCancelled else { return }
            if !refreshAgain { apply(snapshot) }
        }
        if generation == refreshGeneration { refreshTask = nil }
    }

    func loadProducts() async {
        guard !catalog.productIDs.isEmpty, !loadingProducts else { return }
        loadingProducts = true
        defer { loadingProducts = false }
        do {
            let loaded = try await Product.products(for: catalog.productIDs)
                .filter { $0.type == .autoRenewable && $0.subscription != nil }
            var available: [SubscriptionPlan] = []
            for product in loaded {
                guard let subscription = product.subscription,
                    let period = Self.period(subscription.subscriptionPeriod) else { continue }
                let eligible = await subscription.isEligibleForIntroOffer
                var trial: SubscriptionPlan.Trial?
                if eligible, let offer = subscription.introductoryOffer, offer.paymentMode == .freeTrial,
                    let trialPeriod = Self.period(offer.period) {
                    trial = .init(period: trialPeriod, numberOfPeriods: offer.periodCount)
                }
                available.append(.init(id: product.id, name: product.displayName,
                    displayPrice: product.displayPrice, period: period, eligibleTrial: trial))
            }
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            plans = available.sorted { $0.id < $1.id }
            catalogUnavailable = loaded.count != catalog.productIDs.count
        } catch {
            // A catalog/network error cannot erase a verified subscription.
            catalogUnavailable = true
        }
    }

    @discardableResult func purchase(_ productID: String) async -> SubscriptionActionResult {
        guard !actionInProgress else { return .busy }
        let eventID = UUID(), plan = eventPlan(productID)
        guard catalog.productIDs.contains(productID), let product = products[productID] else {
            recordPurchase(id: eventID, action: .purchase, outcome: .unavailable, plan: plan)
            lastResult = .unavailable; return .unavailable
        }
        actionInProgress = true
        defer { actionInProgress = false }
        let outcome: SubscriptionActionResult
        var signedTransaction: Transaction?
        do {
            switch try await purchaseProduct(product) {
            case .success(.verified(let transaction)):
                signedTransaction = transaction
                // A successful sheet alone does not grant access. Re-read signed entitlement state.
                await refreshAccess()
                await transaction.finish()
                outcome = hasPro ? .purchased : .unavailable
            case .success(.unverified):
                accessIssue = .verificationFailed
                outcome = .unverified
            case .userCancelled: outcome = .cancelled
            case .pending: outcome = .pending
            @unknown default: outcome = .unavailable
            }
        } catch StoreKitError.userCancelled { outcome = .cancelled }
        catch { outcome = .failed }
        lastResult = outcome
        if outcome == .pending { pendingPurchase = (eventID, productID, plan) }
        recordPurchase(id: eventID, action: .purchase, outcome: outcome, plan: plan, transaction: signedTransaction)
        await loadProducts() // Eligibility can change after purchase; never promise the old trial again.
        return outcome
    }

    /// The only authentication-capable sync entry point; call exclusively from Restore Purchases.
    @discardableResult func restore() async -> SubscriptionActionResult {
        guard !actionInProgress else { return .busy }
        let eventID = UUID()
        guard !catalog.productIDs.isEmpty else {
            recordPurchase(id: eventID, action: .restore, outcome: .unavailable, plan: .unspecified)
            lastResult = .unavailable; return .unavailable
        }
        actionInProgress = true
        defer { actionInProgress = false }
        let outcome: SubscriptionActionResult
        do {
            try await AppStore.sync()
            await refreshAccess()
            if hasPro { outcome = .restored }
            else if access == .inactive { outcome = .nothingToRestore }
            else { outcome = .unavailable }
        } catch StoreKitError.userCancelled { outcome = .cancelled }
        catch { outcome = .failed }
        lastResult = outcome
        recordPurchase(id: eventID, action: .restore, outcome: outcome, plan: eventPlan(access.grant(at: Date())?.productID))
        await loadProducts()
        return outcome
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        guard !Task.isCancelled else { return }
        guard catalog.productIDs.contains(update.unsafePayloadValue.productID) else { return }
        switch update {
        case .verified(let transaction):
            await refreshAccess()
            guard !Task.isCancelled else { return }
            await transaction.finish()
            if let pending = pendingPurchase, pending.productID == transaction.productID,
               access.grant(at: Date())?.transactionID == transaction.id {
                recordPurchase(id: pending.id, action: .purchase, outcome: .purchased, plan: pending.plan, transaction: transaction)
                pendingPurchase = nil
                if lastResult == .pending { lastResult = .purchased }
            }
            await loadProducts()
        case .unverified:
            accessIssue = .verificationFailed
            await refreshAccess()
        }
    }

    private func recordPurchase(id: UUID, action: LocalEventPayload.PurchaseAction,
        outcome: SubscriptionActionResult, plan: LocalEventPayload.Plan, transaction: Transaction? = nil) {
        let result: LocalEventPayload.PurchaseOutcome
        switch outcome {
        case .purchased: result = .verified
        case .pending: result = .pending
        case .cancelled: result = .cancelled
        case .unverified: result = .unverified
        case .failed: result = .failed
        case .unavailable: result = .unavailable
        case .restored: result = .restored
        case .nothingToRestore: result = .none
        case .busy: return
        }
        let environment: LocalEventPayload.BillingEnvironment
        if let transaction {
            environment = transaction.environment == .xcode ? .xcode : transaction.environment == .sandbox ? .sandbox
                : transaction.environment == .production ? .production : .unknown
        } else { environment = .unknown }
        let trial: LocalEventPayload.Trial = transaction.map { $0.offer?.paymentMode == .freeTrial ? .verifiedFreeTrial : .noFreeTrial } ?? .notEstablished
        events?.emit(.purchaseResult(action: action, outcome: result, plan: plan, trial: trial, store: environment), operationID: id)
    }

    private func apply(_ snapshot: SubscriptionAccess) {
        expiryTask?.cancel(); expiryTask = nil
        accessIssue = nil
        if case .unknown(let issue) = snapshot {
            accessIssue = issue
            // An unavailable recheck can preserve only a still-valid, previously verified grant.
            if access.grant(at: Date()) == nil { access = snapshot }
        } else { access = snapshot }
        guard let grant = access.grant(at: Date()) else { return }
        let delay = max(0, grant.expiresAt.timeIntervalSinceNow)
        expiryTask = Task { @concurrent [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            await self?.refreshAccess()
        }
    }

    private nonisolated static func readAccess(catalog: SubscriptionCatalog) async -> SubscriptionAccess {
        var evidence: [SubscriptionEvidence] = []
        var groups: Set<String> = []
        for await result in Transaction.currentEntitlements {
            let transaction = result.unsafePayloadValue
            guard catalog.productIDs.contains(transaction.productID) else { continue }
            switch result {
            case .unverified:
                evidence.append(.init(productID: transaction.productID, verified: false, expiresAt: nil))
            case .verified:
                evidence.append(.init(productID: transaction.productID, verified: true,
                    expiresAt: transaction.expirationDate, revoked: transaction.revocationDate != nil,
                    upgraded: transaction.isUpgraded, transactionID: transaction.id))
                if let group = transaction.subscriptionGroupID { groups.insert(group) }
            }
        }
        var unavailable = false
        // Ask about every known group: a grace transaction can itself have a future expiration.
        // Only verified renewal information determines its grace deadline, independently of that date.
        for group in groups {
            do {
                for status in try await Product.SubscriptionInfo.status(for: group) where status.state == .inGracePeriod {
                    let candidate = status.transaction.unsafePayloadValue
                    guard catalog.productIDs.contains(candidate.productID) else { continue }
                    guard case .verified(let transaction) = status.transaction,
                        case .verified(let renewal) = status.renewalInfo else {
                        evidence.removeAll { $0.transactionID == candidate.id }
                        evidence.append(.init(productID: candidate.productID, verified: false,
                            expiresAt: nil, transactionID: candidate.id))
                        continue
                    }
                    // Replace this transaction's regular evidence so it cannot outlive the grace deadline.
                    evidence.removeAll { $0.transactionID == transaction.id }
                    guard let graceEnd = renewal.gracePeriodExpirationDate else { unavailable = true; continue }
                    evidence.append(.init(productID: transaction.productID, verified: true,
                        expiresAt: transaction.expirationDate, revoked: transaction.revocationDate != nil,
                        upgraded: transaction.isUpgraded, graceExpiresAt: graceEnd,
                        transactionID: transaction.id))
                }
            } catch { unavailable = true }
        }
        return SubscriptionEvidence.resolve(evidence, catalog: catalog, at: Date(), statusUnavailable: unavailable)
    }

    private static func period(_ value: Product.SubscriptionPeriod) -> SubscriptionPeriod? {
        let unit: SubscriptionPeriod.Unit
        switch value.unit {
        case .day: unit = .day
        case .week: unit = .week
        case .month: unit = .month
        case .year: unit = .year
        @unknown default: return nil
        }
        return .init(value: value.value, unit: unit)
    }
}
