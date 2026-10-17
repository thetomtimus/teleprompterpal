#if DEBUG
import Foundation
import PrototypeSupport

/// UUID-scoped native-test data only. Release builds have no staging entry point.
enum TakeFixtureSeeder {
    static func seed(store: TakeStore, media: MediaService) async throws {
        let marker = await store.root.appendingPathComponent(".fixture-staged")
        guard !FileManager.default.fileExists(atPath: marker.path) else { return }
        guard try await store.load().isEmpty else { return }
        let now = Date()
        let lesson = TakeScriptContext(id: UUID(uuidString: "66DE9D67-0F89-42D8-AC1B-F5767DF1AF11")!, revision: 1, title: "한국어 Lesson (sample)")
        let update = TakeScriptContext(id: UUID(uuidString: "4D2A94E5-2F0D-4C49-A2F1-7AB0E005C222")!, revision: 2, title: "Café Update (sample)")
        let ids = [
            "3231FD8A-2B93-4D0E-AB79-24A3CE000001", "3231FD8A-2B93-4D0E-AB79-24A3CE000002",
            "3231FD8A-2B93-4D0E-AB79-24A3CE000003", "3231FD8A-2B93-4D0E-AB79-24A3CE000004",
            "3231FD8A-2B93-4D0E-AB79-24A3CE000005",
        ].map { UUID(uuidString: $0)! }
        for (index, id) in ids.enumerated() {
            let url = try await store.prepare(id: id, script: index < 2 ? lesson : update,
                                             created: now.addingTimeInterval(Double(-index * 60)))
            if index == 3 { try Data("unfinished sample".utf8).write(to: url); continue }
            try await SampleMovie().make(at: url, rotated: index == 0)
            if index != 2 {
                try await store.complete(id: id, summary: media.inspect(url), note: index == 1
                    ? "Synthetic sample; recording ended after an interruption." : "Synthetic sample recording.",
                    recovery: index == 1 ? .interrupted : nil)
            }
            if index == 4 { try FileManager.default.removeItem(at: url) }
        }
        // Unlisted original: launch reconciliation must find it without a script association.
        let orphan = await store.root.appendingPathComponent("3231FD8A-2B93-4D0E-AB79-24A3CE000006.mov")
        try await SampleMovie().make(at: orphan)
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--p4a-stage-future-edit") {
            let editRoot = await store.root.deletingLastPathComponent().appendingPathComponent("Edits")
            try FileManager.default.createDirectory(at: editRoot, withIntermediateDirectories: true)
            try Data("{\"schemaVersion\":99,\"fixture\":true}".utf8)
                .write(to: editRoot.appendingPathComponent(ids[0].uuidString + ".json"), options: .atomic)
        }
        #endif
        try Data("staged".utf8).write(to: marker, options: .atomic)
    }
}
#endif
