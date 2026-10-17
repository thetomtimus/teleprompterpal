#if DEBUG && targetEnvironment(simulator)
import Foundation
import PrototypeSupport

enum CropFixtureSeeder {
    static func seed(store: TakeStore, media: MediaService) async throws {
        let marker = await store.root.appendingPathComponent(".crop-fixture-staged")
        guard !FileManager.default.fileExists(atPath: marker.path), try await store.load().isEmpty else { return }
        for index in 0..<8 {
            let orientation = SampleMovieOrientation.allCases[index % 4]
            let id = UUID(uuidString: String(format: "C40B0000-0000-4000-8000-%012d", index + 1))!
            let script = TakeScriptContext(
                id: UUID(uuidString: String(format: "C40B1000-0000-4000-8000-%012d", index % 4 + 1))!,
                revision: 1, title: "Crop sample \(index % 4 * 90)")
            let url = try await store.prepare(id: id, script: script)
            try await SampleMovie().make(at: url, orientation: orientation, mirrored: index >= 4)
            try await store.complete(id: id, summary: media.inspect(url),
                note: index >= 4 ? "Mirrored synthetic crop sample." : "Synthetic crop sample.")
        }
        try Data("staged".utf8).write(to: marker, options: .atomic)
    }
}
#endif
