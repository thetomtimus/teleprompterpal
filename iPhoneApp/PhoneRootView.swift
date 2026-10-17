import PhoneLibrary
import PrototypeSupport
import SwiftUI
import UniformTypeIdentifiers

@MainActor struct PhoneRootView: View {
    @State private var library: LibraryModel
    @State private var recorder: PrototypeModel
    @State private var subscriptions: SubscriptionStore
    @State private var localEvents: LocalEventRecorder
    @Environment(\.scenePhase) private var scenePhase
    @State private var importing = false
    @State private var session: ReaderSession?
    @State private var query = ""
    @State private var path = NavigationPath()
    @State private var videosPath = NavigationPath()
    @State private var tab = PhoneSection.scripts
    @State private var onboarding = OnboardingModel.configured()
    @State private var searching = false
    @State private var choosingScript = false
    @State private var recordingSelection: RecordingSelection?
    #if DEBUG
    @State private var physicalExportCheck: PhysicalExportCheck?
    #endif

    init() {
        let events = LocalEventRecorder.configured()
        let billing = SubscriptionStore(catalog: SubscriptionEnvironment.catalog, events: events)
        _localEvents = State(initialValue: events)
        _library = State(initialValue: LibraryModel(events: events))
        _subscriptions = State(initialValue: billing)
        _recorder = State(initialValue: PrototypeModel(events: events, eventAccess: { billing.eventAccess }))
    }

    var body: some View {
        @Bindable var recorder = recorder
        ZStack {
            Group {
                NavigationStack(path: $path) {
                    ScriptGrid(model: library, query: query, open: { path.append($0) }, read: { openReader($0) })
                        .navigationTitle("Scripts")
                        .searchable(
                            text: $query, isPresented: $searching, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search scripts"
                        )
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Menu {
                                    Button("Search Scripts", systemImage: "magnifyingglass") { searching = true }
                                    Button("Import Text", systemImage: "square.and.arrow.down") { importing = true }
                                        .disabled(!library.ready).accessibilityIdentifier("importText")
                                    NavigationLink("Recently Deleted") { DeletedScriptsView(model: library) }
                                    NavigationLink(value: PhoneRoute.subscription) {
                                        Label(subscriptions.isConfigured ? "Subscription" : "Beta Information",
                                            systemImage: subscriptions.isConfigured ? "creditcard" : "info.circle")
                                    }
                                        .accessibilityIdentifier("subscriptionSettings")
                                    NavigationLink(value: PhoneRoute.settings) { Label("Settings & Help", systemImage: "gearshape") }
                                        .accessibilityIdentifier("appSettings")
                                } label: { Text("Edit") }
                                .accessibilityLabel("Library").accessibilityIdentifier("Library")
                            }.referenceChrome()
                            ToolbarItem(placement: .principal) {
                                NavigationLink(value: PhoneRoute.subscription) {
                                    Label(subscriptions.isConfigured ? "Premium" : "Beta",
                                        systemImage: subscriptions.isConfigured ? "diamond" : "info.circle")
                                        .labelStyle(.titleAndIcon).font(.subheadline)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(PhoneTheme.gradient, in: Capsule())
                                }.accessibilityLabel(subscriptions.isConfigured ? "Premium" : "Beta Information")
                                    .accessibilityIdentifier("premiumEntry")
                            }.referenceChrome()
                            ToolbarItem(placement: .topBarTrailing) {
                                NavigationLink(value: PhoneRoute.settings) { Label("Settings & Help", systemImage: "gearshape") }
                                    .accessibilityIdentifier("appSettings")
                            }.referenceChrome()
                        }
                        .navigationDestination(for: UUID.self) { id in
                            ScriptEditorView(model: library, id: id, read: { openReader($0) }, record: { openReader($0, camera: true) })
                        }
                        .navigationDestination(for: PhoneRoute.self) { route in
                            switch route {
                            case .subscription:
                                SubscriptionSettingsView(store: subscriptions, localTest: SubscriptionEnvironment.isLocalTest)
                            case .settings:
                                AppSettingsView(library: library, subscriptions: subscriptions, replayOnboarding: { onboarding.replay() })
                            }
                        }

                }
            }.opacity(tab == .scripts ? 1 : 0).allowsHitTesting(tab == .scripts).accessibilityHidden(tab != .scripts)
            Group {
                NavigationStack(path: $videosPath) {
                    TakeLibraryView(recorder: recorder)
                        .navigationTitle("Videos")

                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                NavigationLink {
                                    AppSettingsView(library: library, subscriptions: subscriptions, replayOnboarding: { onboarding.replay() })
                                } label: { Label("Settings & Help", systemImage: "gearshape") }
                                    .accessibilityIdentifier("appSettings")
                            }.referenceChrome()

                        }
                }
            }.opacity(tab == .videos ? 1 : 0).allowsHitTesting(tab == .videos).accessibilityHidden(tab != .videos)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if tab == .scripts ? path.isEmpty : videosPath.isEmpty {
            RecordingDock(selection: tab, select: { tab = $0 }) {
                RecordCircle(title: "Record", identifier: "recordFromLibrary",
                    enabled: library.ready && recorder.initialized && !recorder.busy) { choosingScript = true }
                    .accessibilityHint("Choose a script to open Camera. Recording starts only when you tap Record in the studio.")
            }
            }
        }
        // Retained library stacks must not remain in VoiceOver's focus order
        // while a modal owns the screen.
        .accessibilityHidden(session != nil || onboarding.presented || recorder.selected != nil || choosingScript)
        .preferredColorScheme(.dark).tint(.white)
        .task {
            await library.initialize()
            await recorder.initialize()
            onboarding.showIfNeeded()
            #if DEBUG && !targetEnvironment(simulator)
            if let request = PhysicalExportCheckRequest() {
                physicalExportCheck = PhysicalExportCheck(request: request, model: recorder)
            } else if let request = PhysicalStudioProbeRequest() {
                await PhysicalStudioProbe(request: request, library: library, model: recorder,
                    openReader: { openReader($0) }, closeReader: { session = nil }).run()
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            library.deactivate()
        }
        .task { await subscriptions.start() }
        .onChange(of: scenePhase) {
            if scenePhase == .active { Task { await subscriptions.start() } }
            else { Task { await localEvents.flush() } }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText]) { result in
            if case .success(let url) = result {
                Task { if let id = await library.importText(url) { path.append(id) } }
            } else if case .failure(let error) = result {
                library.message = error.localizedDescription
            }
        }
        .onOpenURL { url in
            Task {
                await library.initialize()
                if let id = await library.importText(url) { tab = .scripts; path.append(id) }
            }
        }
        .sheet(isPresented: $choosingScript, onDismiss: finishRecordingSelection) {
            RecordingScriptPicker(model: library) { selection in
                recordingSelection = selection
                choosingScript = false
            }
        }
        .fullScreenCover(item: $session, onDismiss: { Task { await library.flush() } }) { active in
            ReaderStudioView(model: recorder, preferences: Binding(
                get: { library.library.preferences },
                set: { library.setPreferences($0); recorder.fontSize = $0.fontSize; recorder.speed = $0.speed }
            ), title: active.title, startInCamera: active.camera, returnToSection: { tab = $0 }) { anchor in
                library.checkpoint(anchor, scriptID: active.id)
            }
            .onChange(of: recorder.playing) { if !recorder.playing { Task { await library.flush() } } }
        }
        .fullScreenCover(isPresented: $onboarding.presented) {
            OnboardingView(model: onboarding, finish: finishOnboarding)
        }
        .sheet(item: $recorder.selected) { take in TakePlaybackView(recorder: recorder, take: take) }
        #if DEBUG
        .fullScreenCover(item: $physicalExportCheck) { check in PhysicalExportCheckView(check: check) }
        #endif
    }

    private func finishOnboarding() {
        if !onboarding.completed, library.ready, library.library.scripts.isEmpty {
            _ = library.create(title: GettingStarted.sampleTitle, text: GettingStarted.sampleText)
            var preferences = library.library.preferences
            preferences.alignment = .center
            preferences.backgroundOpacity = 0.65
            library.setPreferences(preferences)
        }
        onboarding.complete()
    }

    private func finishRecordingSelection() {
        let selection = recordingSelection
        recordingSelection = nil
        switch selection {
        case .script(let id): openReader(id, camera: true)
        case .create:
            if let id = library.create() { tab = .scripts; path.append(id) }
        case nil: break
        }
    }

    private func openReader(_ id: UUID, camera: Bool = false) {
        guard let script = library.script(id), script.deletedAt == nil, !recorder.busy else { return }
        library.select(id)
        recorder.playing = false
        recorder.cameraMode = false
        recorder.cameraReady = false
        recorder.message = nil
        recorder.script = script.document.text
        recorder.initialAnchor = script.anchor
        recorder.fontSize = library.library.preferences.fontSize
        recorder.speed = library.library.preferences.speed
        recorder.takeContext = .init(id: id, revision: script.document.revision, title: script.document.title)
        session = .init(id: id, title: script.document.title, camera: camera)
    }
}

private struct ReaderSession: Identifiable {
    let id: UUID
    let title: String
    let camera: Bool
}

private enum PhoneRoute: Hashable { case subscription, settings }

@MainActor private struct ScriptGrid: View {
    let model: LibraryModel
    let query: String
    let open: (UUID) -> Void
    let read: (UUID) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 320 : 160), alignment: .top)],
                    spacing: 14
                ) {
                    Button {
                        if let id = model.create() { open(id) }
                    } label: {
                        Image(systemName: "plus").font(.title2)
                            .foregroundStyle(PhoneTheme.auxiliaryText)
                            .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? 144 : 214)
                            .background(PhoneTheme.card, in: RoundedRectangle(cornerRadius: 24))
                    }.buttonStyle(.plain).disabled(!model.ready)
                        .accessibilityLabel("Create a script").accessibilityIdentifier("createScriptTile")
                    ForEach(model.library.matching(query)) { script in
                        Button {
                            open(script.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(script.document.title.isEmpty ? "Untitled Script" : script.document.title)
                                    .font(.headline).lineLimit(2).foregroundStyle(.primary)
                                Text(
                                    script.document.text.isEmpty
                                        ? "No text yet" : String(script.document.text.prefix(240))
                                )
                                .font(.subheadline).lineLimit(typeSize.isAccessibilitySize ? 5 : 7).foregroundStyle(PhoneTheme.auxiliaryText)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? 144 : 182, alignment: .topLeading)
                                .padding(16).background(
                                    PhoneTheme.card,
                                    in: RoundedRectangle(cornerRadius: 24))
                        }.buttonStyle(.plain).accessibilityIdentifier("script_\(script.id)")
                            .contextMenu {
                                Button("Read & Record", systemImage: "play") { read(script.id) }
                                Button("Duplicate", systemImage: "doc.on.doc") { _ = model.duplicate(script.id) }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    model.setDeleted(script.id, deleted: true)
                                }
                            }
                    }
                }
                LibrarySaveStatus(model: model)
                if !query.isEmpty, model.library.matching(query).isEmpty {
                    ContentUnavailableView.search(text: query)
                } else if model.ready, model.library.matching("").isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your first take starts here").font(.title3.bold())
                        Text("Create or paste a script, rehearse at your own pace, then record. Your scripts and original takes stay on this iPhone.")
                            .font(.body).foregroundStyle(PhoneTheme.auxiliaryText)
                        Button("Try a sample script", systemImage: "doc.text") {
                            if let id = model.create(title: GettingStarted.sampleTitle, text: GettingStarted.sampleText) { open(id) }
                        }.buttonStyle(.bordered).controlSize(.large).accessibilityIdentifier("trySampleScript")
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                }
            }.padding(16)
        }.background(PhoneTheme.canvas)
    }
}

@MainActor struct LibrarySaveStatus: View {
    let model: LibraryModel
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(typeSize.isAccessibilitySize && model.saveStatus == "Saved on this iPhone" ? "Saved" : model.saveStatus).font(.caption).foregroundStyle(PhoneTheme.auxiliaryText).accessibilityLabel(model.saveStatus).accessibilityIdentifier(
                "librarySaveStatus").fixedSize(horizontal: false, vertical: true)
            if let message = model.message {
                Text(message).font(.callout).accessibilityIdentifier("libraryMessage")
                Button(model.ready ? "Retry Save" : "Retry Opening") {
                    Task { if model.ready { await model.flush() } else { await model.initialize() } }
                }.buttonStyle(.bordered)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor private struct DeletedScriptsView: View {
    let model: LibraryModel
    var body: some View {
        List {
            if model.library.matching("", deleted: true).isEmpty {
                ContentUnavailableView("No deleted scripts", systemImage: "trash")
            }
            ForEach(model.library.matching("", deleted: true)) { script in
                HStack {
                    Text(script.document.title.isEmpty ? "Untitled Script" : script.document.title)
                    Spacer()
                    Button("Restore") { model.setDeleted(script.id, deleted: false) }
                        .accessibilityIdentifier("restore_\(script.id)")
                }
            }
        }.navigationTitle("Recently Deleted").navigationBarTitleDisplayMode(.inline)
    }
}

