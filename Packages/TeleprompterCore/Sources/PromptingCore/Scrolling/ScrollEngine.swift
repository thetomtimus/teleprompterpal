import Foundation

public struct ScrollEngine: Equatable, Sendable {
    public private(set) var offset: Double
    public private(set) var speedPointsPerSecond: Double
    public private(set) var maximumOffset: Double
    public private(set) var phase: PlaybackPhase
    public private(set) var lastUptime: TimeInterval?

    public init(
        offset: Double = 0,
        speedPointsPerSecond: Double = 60,
        maximumOffset: Double = 0
    ) {
        let acceptedMaximum =
            maximumOffset.isFinite && maximumOffset >= 0
            ? maximumOffset
            : 0
        self.maximumOffset = acceptedMaximum
        self.offset = offset.isFinite ? Self.clamp(offset, upperBound: acceptedMaximum) : 0
        self.speedPointsPerSecond =
            Self.isValidSpeed(speedPointsPerSecond)
            ? speedPointsPerSecond
            : 60
        phase = .paused
        lastUptime = nil
    }

    public mutating func apply(_ command: ScrollCommand) -> ScrollTransition {
        let previousOffset = offset
        let previousPhase = phase
        var stopReason: ScrollStopReason?

        switch command {
        case .start(let uptime):
            if phase == .paused, uptime.isFinite {
                phase = .playing
                lastUptime = uptime
            }

        case .tick(let uptime):
            if phase == .playing {
                stopReason = settleElapsedTime(at: uptime).stopReason
            }

        case .pause:
            if phase == .playing {
                phase = .paused
                lastUptime = nil
                stopReason = .commandPause
            }

        case .setSpeed(let pointsPerSecond, let uptime):
            if phase == .playing {
                let settlement = settleElapsedTime(at: uptime)
                stopReason = settlement.stopReason
                if settlement.timingWasValid, Self.isValidSpeed(pointsPerSecond) {
                    speedPointsPerSecond = pointsPerSecond
                }
            } else if Self.isValidSpeed(pointsPerSecond) {
                speedPointsPerSecond = pointsPerSecond
            }

        case .moveBy(let points, let uptime):
            if phase == .playing {
                let settlement = settleElapsedTime(at: uptime, stopsAtMaximum: false)
                stopReason = settlement.stopReason
                if settlement.timingWasValid {
                    if points.isFinite {
                        offset = Self.clamp(offset + points, upperBound: maximumOffset)
                    }
                    if offset == maximumOffset {
                        phase = .paused
                        lastUptime = nil
                        stopReason = .reachedEnd
                    }
                }
            } else if points.isFinite {
                offset = Self.clamp(offset + points, upperBound: maximumOffset)
            }

        case .setMaximumOffset(let newMaximum):
            if phase == .paused, newMaximum.isFinite, newMaximum >= 0 {
                maximumOffset = newMaximum
                offset = Self.clamp(offset, upperBound: newMaximum)
            }

        case .restart:
            if phase == .playing || offset != 0 {
                stopReason = .restart
            }
            offset = 0
            phase = .paused
            lastUptime = nil

        case .suspend(let reason):
            if phase == .playing {
                stopReason = reason.stopReason
            }
            phase = .paused
            lastUptime = nil
        }

        return ScrollTransition(
            offset: offset,
            phase: phase,
            didChangeOffset: offset != previousOffset,
            didChangePhase: phase != previousPhase,
            stopReason: stopReason
        )
    }

    private mutating func settleElapsedTime(
        at uptime: TimeInterval,
        stopsAtMaximum: Bool = true
    ) -> (timingWasValid: Bool, stopReason: ScrollStopReason?) {
        guard uptime.isFinite, let baseline = lastUptime, baseline.isFinite else {
            invalidateTiming()
            return (false, .invalidTimestamp)
        }

        let delta = uptime - baseline
        guard delta.isFinite, delta >= 0 else {
            invalidateTiming()
            return (false, .invalidTimestamp)
        }
        guard delta <= 0.5 else {
            invalidateTiming()
            return (false, .suspensionGap)
        }

        offset = Self.clamp(
            offset + speedPointsPerSecond * delta,
            upperBound: maximumOffset
        )
        lastUptime = uptime

        if stopsAtMaximum, offset == maximumOffset {
            phase = .paused
            lastUptime = nil
            return (true, .reachedEnd)
        }
        return (true, nil)
    }

    private mutating func invalidateTiming() {
        phase = .paused
        lastUptime = nil
    }

    private static func clamp(_ value: Double, upperBound: Double) -> Double {
        min(max(value, 0), upperBound)
    }

    private static func isValidSpeed(_ value: Double) -> Bool {
        value.isFinite && (10...240).contains(value)
    }
}

extension ScrollSuspensionReason {
    fileprivate var stopReason: ScrollStopReason {
        switch self {
        case .explicitSuspension:
            .explicitSuspension
        case .clockUnavailable:
            .clockUnavailable
        }
    }
}
