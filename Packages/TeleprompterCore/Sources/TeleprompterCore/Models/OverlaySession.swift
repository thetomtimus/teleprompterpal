import Foundation
import PromptingCore

public enum OverlayVisibility: Equatable, Sendable {
    case hidden
    case visible
}

public typealias PlaybackPhase = PromptingCore.PlaybackPhase

public enum OverlayChromeState: Equatable, Sendable {
    case shown
    case hidden
}

public enum RecoveryConfirmationState: Equatable, Sendable {
    case required
    case confirmed
}

/// Runtime-only overlay state. This type intentionally has no `Codable`
/// conformance, so playback and current-session identity cannot enter snapshots.
public struct OverlaySession: Equatable, Sendable {
    public var visibility: OverlayVisibility
    public var playbackPhase: PlaybackPhase
    public var readingAnchor: ReadingAnchor
    public var pixelOffset: Double
    public var currentSessionDisplayID: UInt32?
    public var chromeState: OverlayChromeState
    public var recoveryConfirmationState: RecoveryConfirmationState

    public init(
        visibility: OverlayVisibility = .hidden,
        playbackPhase: PlaybackPhase = .paused,
        readingAnchor: ReadingAnchor = ReadingAnchor(),
        pixelOffset: Double = 0,
        currentSessionDisplayID: UInt32? = nil,
        chromeState: OverlayChromeState = .shown,
        recoveryConfirmationState: RecoveryConfirmationState = .required
    ) {
        self.visibility = visibility
        self.playbackPhase = playbackPhase
        self.readingAnchor = readingAnchor
        self.pixelOffset = pixelOffset.isFinite ? pixelOffset : 0
        self.currentSessionDisplayID = currentSessionDisplayID
        self.chromeState = chromeState
        self.recoveryConfirmationState = recoveryConfirmationState
    }
}
