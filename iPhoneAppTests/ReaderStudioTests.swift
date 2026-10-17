import PhoneLibrary
import PromptingCore
import Testing
import UIKit

@testable import TeleprompterPhone

@MainActor private final class ReaderTextEditCounter { var count = 0 }

@Test(arguments: [false, true]) @MainActor
func readerSurfaceHandoffKeepsTheLivePositionAndIgnoresLateDismantle(releaseBeforeClaim: Bool) throws {
    let handoff = ReaderAnchorHandoff()
    let text = Array(repeating: "한국어 café 🎥 Keep this exact place while opening Camera.", count: 300).joined(separator: "\n")
    func make(_ width: CGFloat) -> (PromptReader.Coordinator, ReaderTextView) {
        let coordinator = PromptReader.Coordinator(probe: ReaderProbe(), stopped: {})
        let view = ReaderTextView(usingTextLayoutManager: false)
        view.frame = CGRect(x: 0, y: 0, width: width, height: 240)
        view.textContainerInset = UIEdgeInsets(top: 12, left: 14, bottom: 80, right: 14)
        coordinator.view = view
        coordinator.attach(handoff: handoff)
        coordinator.update(text: text, fontSize: 28, speed: 30, playing: false, restart: 0,
            initialAnchor: .capture(offset: 0, in: text))
        view.layoutManager.ensureLayout(for: view.textContainer)
        view.layoutIfNeeded()
        return (coordinator, view)
    }
    let (old, first) = make(320)
    first.setContentOffset(CGPoint(x: 0, y: 1200), animated: false)
    let expected = try #require(old.currentAnchor())
    #expect(expected.utf16Offset > 100)
    if releaseBeforeClaim { old.invalidate() }
    let (camera, second) = make(280)
    defer { camera.invalidate() }
    let restored = try #require(camera.currentAnchor())
    #expect(abs(restored.utf16Offset - expected.utf16Offset) < 100)
    second.setContentOffset(CGPoint(x: 0, y: second.contentOffset.y + 600), animated: false)
    let newer = try #require(camera.currentAnchor())
    old.invalidate()
    let (returned, third) = make(320)
    defer { returned.invalidate(); _ = third }
    let afterLateDismantle = try #require(returned.currentAnchor())
    #expect(abs(afterLateDismantle.utf16Offset - newer.utf16Offset) < 100)
}

@MainActor private final class ReaderDocumentReadCounter: UITextView {
    var documentReads = 0
    override var text: String! {
        get { documentReads += 1; return super.text }
        set { super.text = newValue }
    }
}

@Test @MainActor func unchangedReaderUpdatesDoNotMaterializeTheTextStorageDocument() {
    let coordinator = PromptReader.Coordinator(probe: ReaderProbe(), stopped: {})
    let view = ReaderDocumentReadCounter(usingTextLayoutManager: false)
    coordinator.view = view
    defer { coordinator.invalidate() }
    let text = String(repeating: "한국어 café 🎥 مرحباً Keep reading smoothly.\n", count: 1000)
    coordinator.update(text: text, fontSize: 28, speed: 30, playing: false, restart: 0)
    view.documentReads = 0
    for _ in 0..<60 {
        coordinator.update(text: text, fontSize: 28, speed: 30, playing: false, restart: 0)
    }
    #expect(view.documentReads == 0)
    let replacement = "A different script. 한국어 🎥"
    coordinator.update(text: replacement, fontSize: 34, speed: 40, playing: false, restart: 0, alignment: .right)
    #expect(view.text == replacement)
    #expect(view.font?.pointSize == 34)
    #expect(view.textAlignment == .right)
}

@Test @MainActor func readingCheckpointsAndOpacityChangesDoNotRewriteTextAttributes() {
    let view = ReaderTextView(usingTextLayoutManager: false)
    let text = String(repeating: "한국어 café 🎥 مرحباً Keep reading smoothly.\n", count: 1000)
    view.text = text
    view.applyAppearance(light: false, opacity: 0.64)
    let edits = ReaderTextEditCounter()
    let observer = NotificationCenter.default.addObserver(
        forName: NSTextStorage.didProcessEditingNotification, object: view.textStorage, queue: .main
    ) { _ in MainActor.assumeIsolated { edits.count += 1 } }
    defer { NotificationCenter.default.removeObserver(observer) }

    for _ in 0..<60 { view.applyAppearance(light: false, opacity: 0.64) }
    view.applyAppearance(light: false, opacity: 0.3)
    #expect(edits.count == 0)
    #expect(view.text == text)
    #expect(view.backgroundColor == UIColor.black.withAlphaComponent(0.3))

    view.applyAppearance(light: true, opacity: 0.3)
    #expect(edits.count > 0, "Changing the foreground still updates the displayed text")
    #expect(view.textColor == .black)
    #expect(view.text == text)
}

@Test(arguments: [0.0, 70.0, 180.0, 600.0])
func panelRemainsInsideTheStageWhenSizeChanges(_ available: Double) {
    for position in [0.0, 0.5, 1.0] {
        var preferences = ReaderPreferences()
        preferences.panelPosition = position
        preferences.panelHeight = 0.85
        let panel = PromptPanelGeometry(availableHeight: available, preferences: preferences)
        #expect(panel.y >= 0)
        #expect(panel.height <= available)
        #expect(panel.y + panel.height <= available)
    }
}

@Test @MainActor func readerContinuesAfterLiveFontAlignmentAndViewportRelayoutNearTheEnd() throws {
    var anchors: [ReadingAnchor] = []
    var stopCount = 0
    let coordinator = PromptReader.Coordinator(probe: ReaderProbe(), checkpoint: { anchors.append($0) }, stopped: { stopCount += 1 })
    let view = ReaderTextView(usingTextLayoutManager: false)
    view.layoutManager.allowsNonContiguousLayout = false
    view.frame = CGRect(x: 0, y: 0, width: 320, height: 220)
    view.textContainerInset = UIEdgeInsets(top: 12, left: 14, bottom: 80, right: 14)
    view.beforeResize = { coordinator.prepareForResize() }
    view.onLayout = { coordinator.layoutChanged() }
    coordinator.view = view
    defer { coordinator.invalidate() }
    let text = Array(repeating: "한국어 café 🎥 مرحباً This line keeps its place while the panel changes.", count: 300).joined(separator: "\n")
    coordinator.update(text: text, fontSize: 28, speed: 30, playing: true, restart: 0,
                       initialAnchor: .capture(offset: text.utf16.count - 2000, in: text))
    coordinator.advance(at: 1)
    coordinator.advance(at: 1 + 1.0 / 60)
    let before = try #require(anchors.last)
    coordinator.update(text: text, fontSize: 38, speed: 30, playing: true, restart: 0, alignment: .center)
    coordinator.advance(at: 2)
    let afterFont = try #require(anchors.last)
    #expect(abs(afterFont.utf16Offset - before.utf16Offset) < 80)
    let fontOffset = view.contentOffset.y
    coordinator.advance(at: 2 + 1.0 / 60)
    #expect(view.contentOffset.y > fontOffset)
    view.bounds.size = CGSize(width: 240, height: 180)
    view.layoutIfNeeded()
    coordinator.advance(at: 3)
    let afterResize = try #require(anchors.last)
    #expect(abs(afterResize.utf16Offset - afterFont.utf16Offset) < 80)
    let resizedOffset = view.contentOffset.y
    coordinator.advance(at: 3 + 1.0 / 60)
    #expect(view.contentOffset.y > resizedOffset)
    #expect(stopCount == 0)
}

@Test @MainActor func manualDragPausesAndDoesNotResumeAfterAControlUpdate() {
    var stopped = false
    let coordinator = PromptReader.Coordinator(probe: ReaderProbe(), stopped: { stopped = true })
    let view = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 220))
    coordinator.view = view
    defer { coordinator.invalidate() }
    let text = String(repeating: "Read at your own pace.\n", count: 150)
    coordinator.update(text: text, fontSize: 28, speed: 30, playing: true, restart: 0)
    coordinator.advance(at: 1)
    coordinator.scrollViewWillBeginDragging(view)
    #expect(stopped)
    coordinator.update(text: text, fontSize: 36, speed: 60, playing: false, restart: 0)
    let pausedOffset = view.contentOffset.y
    coordinator.advance(at: 2)
    #expect(view.contentOffset.y == pausedOffset)
}
