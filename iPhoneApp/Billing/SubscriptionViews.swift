import StoreKit
import SwiftUI

@MainActor struct SubscriptionSettingsView: View {
    let store: SubscriptionStore
    let localTest: Bool
    @State private var showPlans = false
    @State private var management = SubscriptionManagement()
    @State private var document: SubscriptionDocument?

    var body: some View {
        if store.isConfigured {
            configuredContent
        } else {
            BetaInformationView()
        }
    }

    private var configuredContent: some View {
        Form {
            Section("Current access") {
                SubscriptionStatusView(store: store)
                if let result = store.lastResult {
                    Text(SubscriptionCopy.result(result)).accessibilityIdentifier("subscriptionResult")
                }
            }
            Section {
                Button("View Plans") { showPlans = true }.accessibilityIdentifier("viewSubscriptionPlans")
                    .frame(minHeight: 44)
                Button("Restore Purchases") { Task { await store.restore() } }
                    .frame(minHeight: 44).disabled(!store.isConfigured || store.actionInProgress || management.presenting)
                    .accessibilityIdentifier("restoreSubscription")
                Button("Manage Subscription") {
                    Task { await management.open(); await store.refreshAccess(); await store.loadProducts() }
                }
                    .frame(minHeight: 44).disabled(!store.isConfigured || store.actionInProgress || management.presenting)
                    .accessibilityIdentifier("manageSubscription")
                if store.actionInProgress { ProgressView("Waiting for Apple…") }
                if management.presenting { ProgressView("Opening Apple subscription settings…") }
                if let message = management.message {
                    Text(message).accessibilityIdentifier("subscriptionManagementError")
                }
            }
            Section("About this build") { SubscriptionBuildNotice(localTest: localTest) }
            Section {
                Button("Terms (Prototype)") { document = .terms }.frame(minHeight: 44)
                    .accessibilityIdentifier("subscriptionTermsLink")
                Button("Privacy (Prototype)") { document = .privacy }.frame(minHeight: 44)
                    .accessibilityIdentifier("subscriptionPrivacyLink")
            }
        }
        .navigationTitle("Subscription").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPlans) { SubscriptionPaywallView(store: store, localTest: localTest) }
        .sheet(item: $document) { SubscriptionDocumentView(document: $0) }
        .background(SubscriptionSceneCapture(management: management).frame(width: 0, height: 0))
    }
}

@MainActor struct SubscriptionPaywallView: View {
    let store: SubscriptionStore
    let localTest: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selection: String?
    @State private var eventPresentationID = UUID()
    @State private var document: SubscriptionDocument?

    private var selectedPlan: SubscriptionPlan? { store.plans.first { $0.id == selection } }
    private var canPurchase: Bool {
        selectedPlan != nil && store.isConfigured && !store.hasPro && !store.actionInProgress
            && !store.loadingProducts && !store.catalogUnavailable && store.lastResult != .pending
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(localTest ? "Explore Pro in the simulator" : "Explore Pro").font(.title2.weight(.semibold))
                    SubscriptionBuildNotice(localTest: localTest)
                }
                if store.hasPro {
                    Section("Current access") { SubscriptionStatusView(store: store, statusIdentifier: "paywallStatus") }
                }
                if store.loadingProducts {
                    Section { ProgressView("Loading plans…").accessibilityIdentifier("subscriptionLoading") }
                }
                if store.isConfigured {
                    Section("Choose a plan") {
                        ForEach(store.plans) { plan in
                            Button { selection = plan.id } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: selection == plan.id ? "checkmark.circle.fill" : "circle")
                                        .font(.title3).accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(plan.name).font(.headline).foregroundStyle(.primary)
                                        Text(SubscriptionCopy.pricedPeriod(plan)).foregroundStyle(PhoneTheme.auxiliaryText)
                                        if plan.eligibleTrial != nil {
                                            Text("Free trial available").font(.subheadline).foregroundStyle(PhoneTheme.auxiliaryText)
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.frame(minHeight: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(store.actionInProgress)
                                .accessibilityIdentifier("subscriptionPlan_\(plan.id)")
                                .accessibilityAddTraits(selection == plan.id ? .isSelected : [])
                        }
                    }
                }
                if store.catalogUnavailable || (store.isConfigured && !store.loadingProducts && store.plans.isEmpty) {
                    Section {
                        Text("Plans are unavailable. Check your connection and try again.")
                            .accessibilityIdentifier("subscriptionCatalogError")
                        Button("Retry Loading Plans") { Task { await store.loadProducts() } }.frame(minHeight: 44)
                            .disabled(store.loadingProducts || store.actionInProgress)
                    }
                }
                if let plan = selectedPlan {
                    Section {
                        Text(SubscriptionCopy.terms(plan)).font(.subheadline).foregroundStyle(PhoneTheme.auxiliaryText)
                            .accessibilityIdentifier("subscriptionTerms")
                        if let result = store.lastResult {
                            Text(SubscriptionCopy.result(result)).accessibilityIdentifier("paywallResult")
                        }
                        Button {
                            guard canPurchase else { return }
                            Task { await store.purchase(plan.id) }
                        } label: {
                            Text(store.hasPro ? "Pro is active" : store.lastResult == .pending ? "Awaiting Approval"
                                : plan.eligibleTrial == nil ? "Subscribe" : "Start Free Trial")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(.borderedProminent).tint(PhoneTheme.violet).disabled(!canPurchase)
                            .accessibilityIdentifier("subscribe")
                        if store.actionInProgress { ProgressView("Waiting for Apple…") }
                    }
                }
                if selectedPlan == nil, let result = store.lastResult {
                    Section { Text(SubscriptionCopy.result(result)).accessibilityIdentifier("paywallResult") }
                }
                Section {
                    Button("Restore Purchases") { Task { await store.restore() } }.frame(minHeight: 44)
                        .disabled(!store.isConfigured || store.actionInProgress).accessibilityIdentifier("paywallRestore")
                    Button("Terms (Prototype)") { document = .terms }.frame(minHeight: 44)
                        .accessibilityIdentifier("paywallTermsLink")
                    Button("Privacy (Prototype)") { document = .privacy }.frame(minHeight: 44)
                        .accessibilityIdentifier("paywallPrivacyLink")
                }
            }
            .navigationTitle("Pro Plans").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        SubscriptionToolbarLabel(title: "Close", symbol: "xmark", compact: typeSize.isAccessibilitySize)
                    }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("closePaywall")
                }
            }
            .onChange(of: store.plans, initial: true) {
                store.recordPaywall(id: eventPresentationID)
                if !store.plans.contains(where: { $0.id == selection }) {
                    selection = store.plans.first { $0.period.unit == .month }?.id ?? store.plans.first?.id
                }
            }
            .onChange(of: store.loadingProducts) { store.recordPaywall(id: eventPresentationID) }
            .onChange(of: store.catalogUnavailable) { store.recordPaywall(id: eventPresentationID) }
            .onChange(of: store.lastResult) {
                if store.lastResult == .purchased || store.lastResult == .restored { dismiss() }
            }
            .sheet(item: $document) { SubscriptionDocumentView(document: $0) }
        }
    }
}

@MainActor private struct SubscriptionStatusView: View {
    let store: SubscriptionStore
    var statusIdentifier = "subscriptionStatus"
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(status).font(.headline).accessibilityIdentifier(statusIdentifier)
            if let grant = store.access.grant(at: Date()) {
                Text("Access through \(grant.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(PhoneTheme.auxiliaryText)
                if grant.inGracePeriod { Text("Check your payment details in Manage Subscription.") }
            }
            if store.accessIssue != nil {
                Text(store.hasPro ? "The latest check was unavailable. Previously verified access is still valid through the date above."
                    : "Access could not be verified. Your scripts and recordings remain available.")
                    .foregroundStyle(PhoneTheme.auxiliaryText)
                Button("Check Access Again") { Task { await store.refreshAccess() } }.frame(minHeight: 44)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var status: String {
        switch store.access {
        case .unconfigured: "Purchases not configured"
        case .unknown: "Access not confirmed"
        case .inactive: "No active subscription"
        case .active(let grant): grant.isValid(at: Date()) ? (grant.inGracePeriod ? "Pro in billing grace" : "Pro active") : "Access not confirmed"
        }
    }
}

private struct SubscriptionBuildNotice: View {
    let localTest: Bool
    var body: some View {
        Text(localTest
            ? "Simulator test only. Prices and offers are test values, with no real charge. Recording limits, editing and exports are unchanged."
            : "Purchases are not available in this prototype build. Recording limits, editing and exports stay unchanged. Launch prices and paid features have not been set.")
            .foregroundStyle(PhoneTheme.auxiliaryText).accessibilityIdentifier("subscriptionBuildNotice")
    }
}

private enum SubscriptionDocument: String, Identifiable {
    case terms, privacy
    var id: String { rawValue }
    var title: String { self == .terms ? "Prototype Terms" : "Prototype Privacy" }
}

private struct SubscriptionDocumentView: View {
    let document: SubscriptionDocument
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        NavigationStack {
            Form {
                Section("Prototype disclosure") {
                    Text("This is a testing build. These disclosures describe the prototype and are not the final terms or privacy policy for a released app.")
                }
                if document == .terms {
                    Section("Subscriptions") {
                        Text("The simulator's local StoreKit environment simulates purchases, renewals and restores without real payment. Test prices, trials and plan names are fixtures. No production subscription is offered in this build.")
                        Text("Recording limits and access to saved scripts, recordings, editing and exports are unchanged by test subscription status.")
                    }
                } else {
                    Section("Your content") {
                        Text("Scripts, original takes and saved edits are stored locally. Photos, Files and Share deliver a video only when you choose those actions. Their destination apps and providers control their own copies.")
                    }
                    Section("Purchases and measurement") {
                        Text("This build uses Apple's StoreKit APIs for subscription status and purchase actions. It has no RevenueCat or Superwall SDK and no app analytics upload endpoint. Local StoreKit purchases use Apple's test environment.")
                    }
                }
            }
            .navigationTitle(document.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        SubscriptionToolbarLabel(title: "Done", symbol: "checkmark", compact: typeSize.isAccessibilitySize)
                    }
                        .buttonStyle(.borderless)
                }
            }
        }
    }
}

/// Native bar labels stay recognizable when accessibility text has little horizontal room.
private struct SubscriptionToolbarLabel: View {
    let title: String
    let symbol: String
    let compact: Bool
    var body: some View {
        Group {
            if compact { Image(systemName: symbol) }
            else { Text(title) }
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(title)
    }
}
