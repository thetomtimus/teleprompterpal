import AVFoundation
import PrototypeSupport
import Testing
@testable import TeleprompterPhone

struct P6DBetaPolicyTests {
    @Test func recordingOutputHasNoDurationOrFileSizeCapAndRetainsRecoveryHeadroom() {
        let output = AVCaptureMovieFileOutput()
        // Start from restrictive values to verify configuration clears both ceilings.
        output.maxRecordedDuration = CMTime(seconds: 600, preferredTimescale: 600)
        output.maxRecordedFileSize = 1_000_000
        CaptureRecordingPolicy.configure(output)
        #expect(!output.maxRecordedDuration.isValid)
        #expect(output.maxRecordedFileSize == 0)
        #expect(output.minFreeDiskSpaceLimit == CaptureStoragePolicy.outputReserve)
        #expect(output.movieFragmentInterval.seconds == 5)
    }

    @Test @MainActor func betaRemainsUnconfiguredAndCannotStartPurchaseOrRestore() async {
        #expect(SubscriptionEnvironment.catalog == .unconfigured)
        let store = SubscriptionStore(catalog: SubscriptionEnvironment.catalog)
        await store.start()
        #expect(!store.isConfigured && store.plans.isEmpty)
        #expect(await store.purchase("local.teleprompter.pro.monthly") == .unavailable)
        #expect(await store.restore() == .unavailable)
    }
}
