import Testing
@testable import TeleprompterPhone

@Test(arguments: [[], ["--p3d-physical-probe=long"],
    ["--p3d-physical-probe=long", "--p2-test-root=../../ordinary-library"],
    ["--p3d-physical-probe=unknown", "--p2-test-root=00000000-0000-0000-0000-000000000001"],
    ["--p3d-physical-probe=long", "--p2-test-root=00000000-0000-0000-0000-000000000001", "--p3d-camera=unknown"]])
func physicalStudioProbeRejectsUnscopedOrInvalidRequests(arguments: [String]) {
    #expect(PhysicalStudioProbeRequest(arguments: arguments) == nil)
}

@Test func physicalStudioProbePreservesExplicitPoseAndScope() throws {
    let request = try #require(PhysicalStudioProbeRequest(arguments: [
        "--p3d-physical-probe=pose", "--p2-test-root=00000000-0000-0000-0000-000000000001",
        "--p3d-camera=rear", "--p3d-orientation=landscapeRight"]))
    #expect(request.camera == .rear && request.orientation == .landscapeRight && request.mode == .pose)
}
