import Foundation

public enum ScrollSuspensionReason: Equatable, Sendable {
    case explicitSuspension
    case clockUnavailable
}

public enum ScrollStopReason: Equatable, Sendable {
    case commandPause
    case restart
    case reachedEnd
    case suspensionGap
    case invalidTimestamp
    case explicitSuspension
    case clockUnavailable
}

public enum ScrollCommand: Equatable, Sendable {
    case start(at: TimeInterval)
    case tick(at: TimeInterval)
    case pause
    case setSpeed(pointsPerSecond: Double, at: TimeInterval)
    case moveBy(points: Double, at: TimeInterval)
    case setMaximumOffset(Double)
    case restart
    case suspend(ScrollSuspensionReason)
}

public struct ScrollTransition: Equatable, Sendable {
    public let offset: Double
    public let phase: PlaybackPhase
    public let didChangeOffset: Bool
    public let didChangePhase: Bool
    public let stopReason: ScrollStopReason?

    public init(
        offset: Double,
        phase: PlaybackPhase,
        didChangeOffset: Bool,
        didChangePhase: Bool,
        stopReason: ScrollStopReason?
    ) {
        self.offset = offset
        self.phase = phase
        self.didChangeOffset = didChangeOffset
        self.didChangePhase = didChangePhase
        self.stopReason = stopReason
    }
}
