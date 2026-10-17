import Foundation
import PrototypeSupport
import Testing
@testable import TeleprompterPhone

#if DEBUG
@Test(arguments: [[], ["--p4e-device-export=prepare"],
    ["--p4e-device-export=prepare", "--p2-test-root=../ordinary"],
    ["--p4e-device-export=unknown", "--p2-test-root=00000000-0000-4000-8000-000000000001"],
    ["--p4e-device-export=prepare", "--p2-test-root=00000000-0000-4000-8000-000000000001", "--p4e-source-root=00000000-0000-4000-8000-000000000001", "--p4e-source-take=00000000-0000-4000-8000-000000000002"]])
func physicalExportCheckRejectsMissingInvalidAndSharedRoots(arguments: [String]) {
    #expect(PhysicalExportCheckRequest(arguments: arguments) == nil)
}

@Test @MainActor func physicalExportCheckUsesOnlyDesignatedCopyAndRestoresCheckedOutput() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("p4e-device-check-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceRoot = UUID(), testRoot = UUID(), sourceTake = UUID()
    let args = ["--p4e-device-export=prepare", "--p2-test-root=\(testRoot)", "--p4e-source-root=\(sourceRoot)", "--p4e-source-take=\(sourceTake)"]
    let request = try #require(PhysicalExportCheckRequest(arguments: args))
    #expect(PhysicalExportCheckRequest(arguments: args + ["--p3d-physical-probe=long"]) == nil)
    #expect(PhysicalExportCheckRequest(arguments: args + ["--p3d-simulate-capture"]) == nil)
    let source = root.appendingPathComponent("\(sourceRoot)/Takes/\(sourceTake).mov")
    try await SampleMovie().make(at: source)
    let before = try Data(contentsOf: source), capture = TestCapture()
    let model = PrototypeModel(root: root.appendingPathComponent(testRoot.uuidString), capture: capture)
    let check = PhysicalExportCheck(request: request, model: model)
    await check.run(automaticallyPresentDestinations: false)
    #expect(check.report.stage == "ready", "\(check.report.message)")
    #expect(check.report.preset?.width == check.report.preset?.height)
    #expect(check.report.custom?.width == 230 && check.report.custom?.height == 156)
    #expect(check.report.edit?.revision == 2 && check.report.receipts.isEmpty)
    #expect(check.report.sourceSHA == check.report.finalSourceSHA && check.report.copySHA == check.report.sourceSHA)
    #expect(try Data(contentsOf: source) == before)
    #expect(await capture.requests.isEmpty)
    let job = check.report.jobID
    await check.close()
    let reopenedRequest = try #require(PhysicalExportCheckRequest(arguments: args.map { $0 == "--p4e-device-export=prepare" ? "--p4e-device-export=reopen" : $0 }))
    let reopenedModel = PrototypeModel(root: root.appendingPathComponent(testRoot.uuidString), capture: TestCapture())
    let restored = PhysicalExportCheck(request: reopenedRequest, model: reopenedModel)
    await restored.run(automaticallyPresentDestinations: false)
    #expect(restored.report.stage == "ready", "\(restored.report.message)")
    #expect(restored.report.jobID == job)
    #expect(restored.report.checks.contains("saved trim/crop and the same checked job restored without encoding"))
    #expect(try Data(contentsOf: source) == before)
    await restored.close()
}
#endif
