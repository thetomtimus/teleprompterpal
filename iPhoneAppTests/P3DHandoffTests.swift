import Foundation
import Synchronization
import Testing

@testable import TeleprompterPhone

private final class AudioActionProbe: Sendable {
    struct State: Sendable { var activations = 0; var deactivations = 0 }
    private let storage = Mutex(State())
    var state: State { storage.withLock { $0 } }
    var actions: CaptureAudioActions {
        .init(camera: { self.storage.withLock { $0.activations += 1 } },
              playback: { self.storage.withLock { $0.activations += 1 } },
              deactivate: { self.storage.withLock { $0.deactivations += 1 } })
    }
}

#if targetEnvironment(simulator)
@Test func delayedCameraCleanupCannotDeactivateANewerPlaybackLease() async throws {
    let audio = AudioActionProbe(), cameraID = UUID()
    let service = CaptureService(audio: audio.actions)
    // The real service establishes generation ownership before explaining that
    // Simulator has no camera. No process-wide audio session is used here.
    await #expect(throws: CaptureFailure.self) { try await service.configure(side: .front, generation: cameraID) }
    let first = UUID(), second = UUID()
    try await service.preparePlayback(id: first)
    #expect(audio.state.activations == 1)
    let before = audio.state.deactivations
    #expect(before == 1)
    await service.stopPreview(generation: cameraID)
    await service.suspend(generation: cameraID)
    #expect(audio.state.deactivations == before)
    try await service.preparePlayback(id: second)
    #expect(audio.state.deactivations == before)
    await service.finishPlayback(id: first)
    #expect(audio.state.deactivations == before)
    await service.finishPlayback(id: second)
    #expect(audio.state.deactivations == before + 1)
    await service.finishPlayback(id: second)
    #expect(audio.state.deactivations == before + 1)
    try await service.preparePlayback(id: UUID())
    let beforeShutdown = audio.state.deactivations
    await service.shutdown()
    #expect(audio.state.deactivations == beforeShutdown + 1)
}
#endif

#if DEBUG && targetEnvironment(simulator)
@Test(arguments: [[], ["--p3d-simulate-capture"],
    ["--p3d-simulate-capture", "--p2-test-root=../../normal-library"],
    ["--p3d-stage-script", "--p2-test-root=not-a-uuid"]])
func simulatorCaptureAndScriptFixturesRejectUnscopedArguments(arguments: [String]) {
    #expect(!SimulatorIntegrationFixture.accepts(SimulatorIntegrationFixture.captureFlag, arguments: arguments))
    #expect(!SimulatorIntegrationFixture.accepts(SimulatorIntegrationFixture.scriptFlag, arguments: arguments))
}

@Test func simulatorFixturesRequireAValidUUIDAndExplicitOptIn() {
    let root = "--p2-test-root=\(UUID())"
    #expect(!SimulatorIntegrationFixture.accepts(SimulatorIntegrationFixture.captureFlag, arguments: [root]))
    #expect(SimulatorIntegrationFixture.accepts(SimulatorIntegrationFixture.captureFlag,
        arguments: [root, SimulatorIntegrationFixture.captureFlag]))
    #expect(SimulatorIntegrationFixture.accepts(SimulatorIntegrationFixture.scriptFlag,
        arguments: [root, SimulatorIntegrationFixture.scriptFlag]))
}
#endif
