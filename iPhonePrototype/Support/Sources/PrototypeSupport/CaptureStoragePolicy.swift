import Foundation

public enum CaptureStoragePolicy {
    // P1's 600-second original used 1,155,797,360 bytes. Reserve 50% above that
    // measured size plus finalization headroom; this is a preflight, not a size guarantee.
    public static let measuredTenMinuteBytes: Int64 = 1_155_797_360
    public static let finalizationReserve: Int64 = 256 * 1024 * 1024
    public static let outputReserve: Int64 = 128 * 1024 * 1024
    public static let requiredFreeBytes = measuredTenMinuteBytes * 3 / 2 + finalizationReserve

    @concurrent public static func availableCapacity(at directory: URL) async throws -> Int64 {
        let values = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let capacity = values.volumeAvailableCapacityForImportantUsage, capacity >= 0 else {
            throw CocoaError(.fileReadUnknown)
        }
        return capacity
    }
}
