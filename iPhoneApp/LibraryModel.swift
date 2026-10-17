import Foundation
import Observation
import PhoneLibrary
import PromptingCore
import PrototypeSupport
import UIKit

@MainActor @Observable final class LibraryModel {
    private(set) var library = ScriptLibrary()
    private(set) var ready = false
    private(set) var saveStatus = "Opening scripts…"
    var message: String?
    private let store: LibraryStore
    @ObservationIgnored private let events: LocalEventRecorder?
    @ObservationIgnored private var readyScripts: Set<UUID> = []
    @ObservationIgnored private var origins: [UUID: LocalEventPayload.ScriptOrigin] = [:]
    private var saveTask: Task<Void, Never>?
    private var saveGeneration = UUID()
    private var savedRevision: UInt64 = 0
    private var backgroundSave = UIBackgroundTaskIdentifier.invalid
    private var loadTask: Task<LibraryLoad, any Error>?
    #if DEBUG && targetEnvironment(simulator)
    private let stageIntegrationScript: Bool
    #endif

    init(root: URL? = nil, events: LocalEventRecorder? = nil) {
        self.events = events
        #if DEBUG && targetEnvironment(simulator)
        stageIntegrationScript = root == nil && SimulatorIntegrationFixture.accepts(SimulatorIntegrationFixture.scriptFlag)
        #endif
        var location =
            root
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PhoneScripts", isDirectory: true)
        #if DEBUG
        if root == nil,
            let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--p2-test-root=") }),
            let id = UUID(uuidString: String(argument.dropFirst("--p2-test-root=".count)))
        {
            location = location.appendingPathComponent("UITests/\(id.uuidString)")
            if ProcessInfo.processInfo.arguments.contains("--p2-stage-import-fixture") {
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fixture = documents.appendingPathComponent("P2-Import-\(id.uuidString).txt")
                try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
                try? Data("한국어 café 🎥\nReading a script should feel natural.\nThis file is imported through the Files picker.\n".utf8)
                    .write(to: fixture, options: .withoutOverwriting)
            }
        }
        #endif
        store = LibraryStore(root: location)
    }

    func initialize() async {
        guard !ready else { return }
        let loading = loadTask ?? Task { @concurrent [store] in try await store.load() }
        loadTask = loading
        defer { loadTask = nil }
        do {
            let result = try await loading.value
            guard !ready else { return }
            library = result.library
            readyScripts = Set(library.scripts.filter { !$0.document.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.map(\.id))
            savedRevision = library.revision
            ready = true
            saveStatus = "Saved on this iPhone"
            if result.recoveredFromBackup {
                message =
                    "Recovered an earlier saved library. Recent changes may be missing; the damaged file has been kept."
            }
            #if DEBUG && targetEnvironment(simulator)
            if stageIntegrationScript, library.scripts.isEmpty {
                let text = SimulatorIntegrationFixture.text
                if let id = create(title: SimulatorIntegrationFixture.title, text: text) {
                    checkpoint(.capture(offset: text.utf16.count - 6000, in: text), scriptID: id)
                    await flush()
                }
            }
            #endif
        } catch {
            message = error.localizedDescription
            saveStatus = "Scripts unavailable"
        }
    }

    func script(_ id: UUID) -> ScriptRecord? { library.scripts.first { $0.id == id } }
    @discardableResult func create(title: String = "Untitled Script", text: String = "",
        origin: LocalEventPayload.ScriptOrigin = .createOrPaste) -> UUID? {
        guard ready else { return nil }
        guard text.utf8.count <= TextImport.maximumBytes else {
            message = LibraryError.tooLarge.localizedDescription
            return nil
        }
        let record = ScriptRecord(title: title, text: text)
        library.scripts.append(record)
        origins[record.id] = origin
        library.selectedScriptID = record.id
        changed()
        return record.id
    }

    func edit(_ id: UUID, title: String, text: String) {
        guard ready, let index = library.scripts.firstIndex(where: { $0.id == id }),
            library.scripts[index].document.title != title || library.scripts[index].document.text != text
        else { return }
        do {
            try library.scripts[index].edit(title: title, text: text)
            changed()
        } catch { message = error.localizedDescription }
    }

    @discardableResult func duplicate(_ id: UUID) -> UUID? {
        guard let source = script(id) else { return nil }
        return create(title: source.document.title + " copy", text: source.document.text, origin: .duplicated)
    }

    func setDeleted(_ id: UUID, deleted: Bool) {
        guard ready, let index = library.scripts.firstIndex(where: { $0.id == id }) else { return }
        library.scripts[index].deletedAt = deleted ? Date() : nil
        if deleted, library.selectedScriptID == id { library.selectedScriptID = nil }
        changed()
    }

    func select(_ id: UUID) {
        library.selectedScriptID = id
        changed()
    }
    func checkpoint(_ anchor: ReadingAnchor, scriptID: UUID) {
        guard let index = library.scripts.firstIndex(where: { $0.id == scriptID }),
            library.scripts[index].anchor != anchor
        else { return }
        library.scripts[index].anchor = anchor.clamped(to: library.scripts[index].document.text)
        do { try library.changed() } catch {
            message = error.localizedDescription
            return
        }
        // Reading checkpoints are coarse and write at most every ten seconds, plus pause/exit flush.
        if saveTask == nil { schedule(after: .seconds(10)) }
    }

    func setPreferences(font: Double, speed: Double) {
        var preferences = library.preferences
        preferences.fontSize = font
        preferences.speed = speed
        setPreferences(preferences)
    }

    func setPreferences(_ value: ReaderPreferences) {
        var preferences = value
        preferences.normalize()
        guard preferences != library.preferences else { return }
        library.preferences = preferences
        changed()
    }

    func importText(_ url: URL) async -> UUID? {
        guard ready else { return nil }
        do {
            let text = try await store.readImportedText(url)
            let title = url.deletingPathExtension().lastPathComponent
            return create(title: title.isEmpty ? "Imported Script" : title, text: text, origin: .imported)
        } catch {
            message = error.localizedDescription
            return nil
        }
    }

    func flush() async {
        saveGeneration = UUID()
        saveTask?.cancel()
        saveTask = nil
        await persist()
    }

    func deactivate() {
        guard ready, library.revision > savedRevision else { return }
        if backgroundSave == .invalid {
            backgroundSave = UIApplication.shared.beginBackgroundTask(withName: "Save scripts") { [weak self] in
                MainActor.assumeIsolated { self?.endBackgroundSave() }
            }
        }
        Task {
            await flush()
            await events?.flush()
            endBackgroundSave()
        }
    }

    private func endBackgroundSave() {
        guard backgroundSave != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundSave)
        backgroundSave = .invalid
    }

    private func changed() {
        do {
            try library.changed()
            schedule(after: .milliseconds(300))
        } catch { message = error.localizedDescription }
    }
    private func schedule(after delay: Duration) {
        saveTask?.cancel()
        let generation = UUID()
        saveGeneration = generation
        saveStatus = "Saving…"
        saveTask = Task { [weak self] in
            do { try await Task.sleep(for: delay) } catch { return }
            guard let self, generation == saveGeneration else { return }
            saveTask = nil
            await persist()
        }
    }
    private func persist() async {
        guard ready, library.revision > savedRevision else { return }
        let snapshot = library
        saveStatus = "Saving…"
        do {
            try await store.save(snapshot)
            for script in snapshot.scripts where !readyScripts.contains(script.id)
                && !script.document.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                events?.emit(.scriptReady(origin: origins[script.id] ?? .createOrPaste,
                    length: .characters(script.document.text.count)), operationID: script.id)
                readyScripts.insert(script.id)
                origins.removeValue(forKey: script.id)
            }
            savedRevision = max(savedRevision, snapshot.revision)
            message = nil
            if library.revision == savedRevision { saveStatus = "Saved on this iPhone" }
        } catch LibraryError.staleSnapshot {
            if library.revision > savedRevision { schedule(after: .milliseconds(300)) }
        } catch {
            message = "Could not save your changes. They are still on screen. \(error.localizedDescription)"
            saveStatus = "Changes not saved"
        }
    }
    isolated deinit {
        saveTask?.cancel()
        if backgroundSave != .invalid { UIApplication.shared.endBackgroundTask(backgroundSave) }
    }
}
