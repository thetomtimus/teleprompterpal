#!/usr/bin/env python3
"""RED/GREEN contract for the Milestone 6 evidence-epoch validator."""

from __future__ import annotations

import hashlib
import importlib.util
import inspect
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "validate_project_structure", ROOT / "Scripts/validate_project_structure.py"
)
assert SPEC is not None and SPEC.loader is not None
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)

EXPECTED_PLAN_COMMIT = "3c1aadd9fb50ab6f335580ebd72e6609f2cfa2f0"
EXPECTED_PLAN_PARENT = "1ac13dbbdae1c53eea06033c353d22ab0919e8a5"
EXPECTED_PLAN_PATH = "docs/plans/2026-07-16-milestone-6-reference-faithful-visual-polish.md"
EXPECTED_M5_TREE = "3d90bcd2c1851b36e0adc774c99a2416da7ba5b8"
EXPECTED_M5_MANIFEST_SHA256 = "29a38045cb4f01c29c5973baeb3ec57de0cda249d52e82e385481a2724f20eae"

EXPECTED_PROTECTED_PATHS = (
    "HANDOFF.md",
    "IMPLEMENTATION_PLAN.md",
    "PRD.md",
    "design/concept.html",
    "design/teleprompter-concept.png",
    "references/teleprompter-ui-reference.png",
    "docs/plans/2026-07-12-milestone-0-stabilization.md",
    "docs/plans/2026-07-12-milestone-1-core-state-durability.md",
    "docs/plans/2026-07-14-milestone-2-controller-editor-display-safety.md",
    "docs/plans/2026-07-15-milestone-3-smooth-rehearsal-scrolling.md",
    "docs/plans/2026-07-15-milestone-4-global-hotkeys-focus-menu.md",
    "docs/plans/2026-07-15-milestone-5-accessibility-performance-hardening.md",
    EXPECTED_PLAN_PATH,
    "docs/validation/m0-phase-a-causal-decision-2026-07-14.md",
    "docs/validation/m0-phase-b-physical-selection-2026-07-14.md",
    "docs/validation/m2-controller-editor-display-safety-result.md",
    "docs/validation/m5-accessibility-result.md",
    "docs/validation/m5-display-crash-quit-result.md",
    "docs/validation/overlay-proof-result.md",
    "docs/validation/overlay-proof-template.md",
    "docs/validation/performance-result.md",
    "docs/validation/source-artifact-checksums.sha256",
)

EXPECTED_FINAL_EVIDENCE_PATHS = (
    "docs/validation/visual-result.md",
    ".omx/handoff/private-presenter-m6/MAC-CONTINUATION.md",
    ".omx/handoff/private-presenter-m6/m6-artifacts.sha256",
    ".omx/handoff/private-presenter-m6/m6-source-files.sha256",
    ".omx/handoff/private-presenter-m6/private-presenter-m6-source.tar",
    ".omx/handoff/private-presenter-m6/private-presenter-m6-wsl.bundle",
)
EXPECTED_RESULT_PATH = "docs/validation/visual-result.md"
EXPECTED_CONTINUATION_DIR = ".omx/handoff/private-presenter-m6"
EXPECTED_CONTINUATION_FILES = (
    "MAC-CONTINUATION.md",
    "m6-artifacts.sha256",
    "m6-source-files.sha256",
    "private-presenter-m6-source.tar",
    "private-presenter-m6-wsl.bundle",
)
EXPECTED_ARTIFACT_ENTRIES = (
    "MAC-CONTINUATION.md",
    "m6-source-files.sha256",
    "private-presenter-m6-source.tar",
    "private-presenter-m6-wsl.bundle",
)
EXPECTED_SCREENSHOT_STATES = (
    "unlocked",
    "locked",
    "focus-hidden",
    "bright-background",
    "active-band",
)
EXPECTED_REFERENCE_HASHES = (
    (
        "teleprompter-ui-reference",
        "352437f2fc06efbab7f7ea7ad910f56eaa65c87eaf2574d30df742019ea9ac92",
    ),
    (
        "teleprompter-concept",
        "d8a42232d19d87a23b1a2aacbc1970cae75bd0f0c7a3b523c701c5a2fa79762e",
    ),
)
EXPECTED_RESULT_PENDING_FIELDS = (
    "Status: PENDING",
    "WSL static verification record: PENDING",
    "Source SHA: PENDING",
    "Source tree SHA: PENDING",
    "Release executable SHA-256: PENDING",
    "Controlled Mac host identifier: PENDING",
    "macOS/Xcode/Swift toolchain: PENDING",
    "Swift compilation: PENDING",
    "AppKit/TextKit/Core Graphics render: PENDING",
    "Screenshot capture: PENDING",
    "Independent visual review: PENDING",
    "M3 native predecessor evidence: PENDING",
    "M4 native predecessor evidence: PENDING",
    "M5 native predecessor evidence: PENDING",
    "Keyboard accessibility: PENDING",
    "Full Keyboard Access: PENDING",
    "VoiceOver: PENDING",
    "Accessibility Inspector: PENDING",
    "Increase Contrast: PENDING",
    "Differentiate Without Color: PENDING",
    "Reduce Motion: PENDING",
    "M5 performance replay: PENDING",
    "Release Instruments: PENDING",
    "Keynote: PENDING",
    "Private display: PENDING",
    "Audience display: PENDING",
    "Physical presenter result: PENDING",
)
EXPECTED_LEDGER_TITLES = (
    "Keep visual work inside its exact evidence epoch",
    "Make the reading card opaque before making it decorative",
    "Keep long-form type spacious without replacing the script",
    "Make reference chrome useful without taking Keynote input",
    "Preserve readable structure through every contained resize",
    "Detect visual drift without a brittle snapshot dependency",
    "Keep visual acceptance reproducible and honestly host-bound",
    "Make hosted controls match their full semantic targets",
    "Keep the active band current without rebuilding text",
    "Make the semantic oracle deterministic without sharing product state",
    "Make hosted evidence prove the real private presenter",
    "Keep every review repair auditable on the Mac",
    "Accept only the verified reconstructed M5 handoff",
    "Make the recovered source compile before packaging",
    "Import the native signposter module with its real name",
    "Keep teardown on the main actor under Swift 6",
    "Record the actor teardown path in final scope",
    "Return every accessibility retry decision explicitly",
    "Make Carbon callbacks and messages isolation-correct",
    "Keep the display-link target and teardown actor-safe",
    "Keep dense hosted diagnostics valid Swift",
    "Keep UI lifecycle and focus queries Xcode 16 compatible",
    "Keep menu lifecycle UI tests on MainActor",
    "Launch menu UI application lazily on MainActor",
    "Keep controller UI cleanup inside MainActor tests",
    "Import Carbon constants in native hot-key tests",
    "Keep Carbon status expectations type-exact",
    "Keep visual anchor tests aligned with the context API",
    "Keep accessibility store fixtures inside MainActor tests",
    "Keep native support fixtures Xcode 16 type-exact",
    "Record Xcode 16 support spellings in final scope",
    "Convert the native bitmap into explicit sRGB",
    "Record the bitmap conversion in focused support scope",
    "Keep mutable viewport replacement inside MainActor state",
    "Stabilize final native AppKit integration fixtures",
    "Record the native display fixture in final scope",
    "Use protocol AX traversal and valid native geometry",
    "Record protocol AX traversal in final markers",
)
EXPECTED_LORE_TRAILER_KEYS = (
    "Constraint",
    "Rejected",
    "Confidence",
    "Scope-risk",
    "Reversibility",
    "Directive",
    "Tested",
    "Not-tested",
    "Related",
)
EXPECTED_NATIVE_REPLAY_PAIR_LABELS = (1, 2, 3, 4, 5, 7, 8, 9, 10)
EXPECTED_STAGE_RECONSTRUCTION_MARKERS = (
    "reconstruct_stage_handoff() {",
    'cp "$FINAL_M6_HANDOFF/MAC-CONTINUATION.md" "$stage_handoff/MAC-CONTINUATION.md"',
    'git diff --name-only --diff-filter=ACMR "$M6_PLAN_SHA..$stage_sha" | LC_ALL=C sort',
    "--sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner",
    'git bundle create "$stage_handoff/private-presenter-m6-wsl.bundle" HEAD',
    'for role in red green; do',
    'git switch --detach "$sha"',
    'reconstruct_stage_handoff "$green_sha" "$green_tree" "$pair_index"',
    "python3 -B Scripts/test_validate_project_structure_m6.py",
    "-only-testing:PrivatePresenterAppTests/OverlayVisualSnapshotTests",
)
EXPECTED_PRIOR_LEDGER_PAIRS = (
    ("726c781f4fd09e0bdc69c37a0f424c3979451736", "401fa11f385fb3d56aaa4864d3a316853e59b4e3"),
    ("8acd1c19333bf4f5f9673409a4672773043f9ce8", "f1daca33ef87b24421fa4a6b38437cce8daa10f5"),
    ("dbb7db12b346936c2799f3980ba411925bb01d6a", "a202a88d27b3be1f9327b1b9843c21b7bba1710a"),
    ("980df38b6d18e4490ccaef185670cd23dba04e2f", "2c655f2dd58675822bb5c095db78ff67f3f41e9e"),
    ("db025cd6ff342f9c7d06eb9994593d41a270c143", "491a0d415512e08a91119abf4d24f96bb17b3869"),
    ("c70000807063c3a2a6e795e40917a6edc3878f61", "4876163282db70c9651dfa511602d027a4d45900"),
)

EXPECTED_M3_REQUIRED_PATHS = (
    "PrivatePresenterApp/Overlay/OverlayQuickControlsView.swift",
)
EXPECTED_M3_NAMED_TESTS = (
    "testHeaderHasTitlePlaybackLockAndSettingsInOrder",
    "testQuickPillHasSevenTypedActionsInOrder",
    "testHeaderAndPillUseFrozenSymbolAndStateVariantsAtEveryTier",
    "testEveryM6IconHasDynamicSemanticsTooltipAndFortyFourPointTarget",
    "testHeaderDragNeverInterceptsControls",
    "testLockedVisibleAndHiddenChromeAreNotInteractiveOrAccessibilityNavigable",
    "testOnlyUnlockedSettingsDispatchesShowControllerWithoutActivationWorkaround",
    "testFocusModeFadesChromeWithoutChangingReaderGeometryOrAnchor",
    "testReduceMotionRemovesOnlyDecorativeFade",
)
EXPECTED_M3_SOURCE_MARKERS = (
    ("header-title", "PrivatePresenterApp/Overlay/OverlayChromeView.swift", "model.document.title", 1),
    ("header-playback-command", "PrivatePresenterApp/Overlay/OverlayChromeView.swift", "model.send(.togglePlayback)", 1),
    ("header-lock-command", "PrivatePresenterApp/Overlay/OverlayChromeView.swift", "model.send(.toggleLock)", 1),
    ("header-settings-command", "PrivatePresenterApp/Overlay/OverlayChromeView.swift", "model.send(.showController)", 1),
    ("header-document-symbol", "PrivatePresenterApp/Overlay/OverlayChromeView.swift", '"doc.text"', 1),
    ("header-drag-region", "PrivatePresenterApp/Overlay/OverlayChromeView.swift", '"privatePresenter.headerDragRegion"', 1),
    ("quick-seven-actions", "PrivatePresenterApp/Overlay/OverlayQuickControlsView.swift", "static let actionIdentifiers = [", 1),
    ("quick-smaller-command", "PrivatePresenterApp/Overlay/OverlayQuickControlsView.swift", ".setFontSize(model.preferences.fontSizePoints - PresenterAccessibility.fontSizeStep)", 1),
    ("quick-larger-command", "PrivatePresenterApp/Overlay/OverlayQuickControlsView.swift", ".setFontSize(model.preferences.fontSizePoints + PresenterAccessibility.fontSizeStep)", 1),
    ("quick-slower-command", "PrivatePresenterApp/Overlay/OverlayQuickControlsView.swift", ".setSpeed(model.preferences.speedPointsPerSecond - PresenterAccessibility.speedStep)", 1),
    ("quick-faster-command", "PrivatePresenterApp/Overlay/OverlayQuickControlsView.swift", ".setSpeed(model.preferences.speedPointsPerSecond + PresenterAccessibility.speedStep)", 1),
    ("quick-focus-command", "PrivatePresenterApp/Overlay/OverlayQuickControlsView.swift", ".setFocusModeEnabled(!model.preferences.isFocusModeEnabled)", 1),
    ("root-header-mount", "PrivatePresenterApp/Overlay/OverlayRootView.swift", "OverlayChromeView(", 1),
    ("root-pill-mount", "PrivatePresenterApp/Overlay/OverlayRootView.swift", "OverlayQuickControlsView(", 1),
    ("root-opacity-only", "PrivatePresenterApp/Overlay/OverlayRootView.swift", ".opacity(presentation.opacity)", 2),
    ("root-hit-policy", "PrivatePresenterApp/Overlay/OverlayRootView.swift", ".allowsHitTesting(presentation.allowsInteraction)", 2),
    ("root-ax-policy", "PrivatePresenterApp/Overlay/OverlayRootView.swift", ".accessibilityHidden(presentation.isAccessibilityHidden)", 2),
    ("central-header-id", "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift", '"privatePresenter.headerPlayback"', 1),
    ("central-pill-id", "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift", '"privatePresenter.quickFocus"', 1),
)

EXPECTED_M4_NAMED_TESTS = (
    "testResizeMatrixKeepsEveryPixelAndControlInsideRoundedSurface",
    "testToolbarNeverOverlapsBandOrFinalLine",
    "testHundredResizesPreserveAnchorAndAvoidTextReplacement",
    "testEveryHeaderAndResizeFrameRemainsContainedExactlyOnce",
    "testCompactTierDenseHitGridRoutesEveryControlBeforeResize",
    "testAllEightResizeOperationsRemainReachableOutsideControlsAtEveryTier",
)
EXPECTED_M4_SOURCE_MARKERS = (
    ("card-bounds", "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift", "var cardBounds: CGRect {", 1),
    ("header-frame", "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift", "var headerFrame: CGRect {", 1),
    ("reading-frame", "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift", "var readingFrame: CGRect {", 1),
    ("toolbar-frame", "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift", "var toolbarFrame: CGRect {", 1),
    ("quick-regions", "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift", "var quickControlRegions: [ControlRegion] {", 1),
    ("header-regions", "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift", "var headerControlRegions: [ControlRegion] {", 1),
    ("resize-regions", "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift", "var resizeRegions: [ResizeRegion] {", 1),
    ("hit-resolver", "PrivatePresenterApp/Overlay/OverlayRootView.swift", "struct OverlayHitRegionResolver {", 1),
    ("half-open-x", "PrivatePresenterApp/Overlay/OverlayRootView.swift", "point.x >= rect.minX && point.x < rect.maxX", 1),
    ("half-open-y", "PrivatePresenterApp/Overlay/OverlayRootView.swift", "point.y >= rect.minY && point.y < rect.maxY", 1),
    ("frozen-resize-probes", "PrivatePresenterApp/Overlay/OverlayRootView.swift", "static func frozenResizeProbes(size: CGSize) -> [ResizeProbe] {", 1),
    ("resize-layer", "PrivatePresenterApp/Overlay/OverlayChromeView.swift", "OverlayResizeInteractionLayer(", 1),
    ("title-below-resize", "PrivatePresenterApp/Overlay/OverlayChromeView.swift", ".zIndex(0)", 1),
    ("resize-below-controls", "PrivatePresenterApp/Overlay/OverlayChromeView.swift", ".zIndex(1)", 1),
    ("controls-above-resize", "PrivatePresenterApp/Overlay/OverlayChromeView.swift", ".zIndex(2)", 1),
    ("responsive-reader-frame", "PrivatePresenterApp/Overlay/ReaderTextView.swift", "let readingFrame = metrics.readerViewportFrame", 1),
    ("root-layout-size", "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift", "layoutSize: hostedView?.bounds.size", 2),
    ("layout-size-authority", "PrivatePresenterApp/Overlay/ReaderTextSystem.swift", "layoutSize: NSSize? = nil", 1),
    ("will-change-callback", "PrivatePresenterApp/Overlay/ReaderTextView.swift", "onBoundsWillChange()", 1),
    ("changed-callback", "PrivatePresenterApp/Overlay/ReaderTextView.swift", "onBoundsChanged()", 1),
)

EXPECTED_M5_VISUAL_REQUIRED_PATHS = (
    "PrivatePresenterAppTests/M6VisualTestSupport.swift",
)
EXPECTED_M5_VISUAL_NAMED_TESTS = (
    "testActualOverlayRenderMatchesIndependentSemanticBaseline",
    "testSemanticComparatorRejectsEveryNamedCorruption",
    "testIndependentContinuousMaskRejectsWrongRadiusAndStyle",
    "testRenderMatrixPreservesContainmentOpacityAndFocusGeometry",
    "testNativeRenderAttributesAndFramesRemainExplicit",
)
EXPECTED_M5_VISUAL_SOURCE_MARKERS = (
    ("canonical-size", "static let canonicalSize = CGSize(width: 1_036, height: 460)", 1),
    ("two-x-scale", "static let backingScale: CGFloat = 2", 1),
    ("fixed-locale", 'Locale(identifier: "en_US_POSIX")', 1),
    ("left-to-right", ".environment(\\.layoutDirection, .leftToRight)", 1),
    ("dark-aqua", "NSAppearance(named: .darkAqua)", 1),
    ("animations-disabled", "NSAnimationContext.runAnimationGroup", 1),
    ("named-srgb", "CGColorSpace(name: CGColorSpace.sRGB)", 4),
    (
        "literal-continuous-mask",
        "RoundedRectangle(cornerRadius: 30, style: .continuous).path(in: literalBounds).cgPath",
        1,
    ),
    ("literal-oracle", "static func makeCanonicalSemanticOracle() throws -> SemanticOracle", 1),
    ("glyph-mask", "static func literalGlyphAndIconExclusionMask()", 1),
    ("two-pixel-edge-mask", "static func literalTwoDevicePixelEdgeMask()", 1),
    ("alpha-threshold", "interiorAlphaFraction == 1", 1),
    ("gradient-threshold", "gradientMaximumChannelError <= 2", 1),
    ("geometry-threshold", "minimumRegionIntersectionOverUnion >= 0.98", 1),
    ("region-threshold", "bandAndPillMeanAbsoluteError <= 4.0 / 255", 1),
    ("mean-threshold", "structuralMeanAbsoluteError <= 3.0 / 255", 1),
    ("p99-threshold", "structuralP99AbsoluteError <= 8.0 / 255", 1),
    ("outlier-threshold", "structuralOutlierFraction <= 0.01", 1),
    ("top-corruption", "case topGradientProbe", 1),
    ("middle-corruption", "case middleGradientProbe", 1),
    ("bottom-corruption", "case bottomGradientProbe", 1),
    ("alpha-corruption", "case interiorAlphaPatch", 1),
    ("corner-corruption", "case exteriorCorner", 1),
    ("divider-corruption", "case translatedDivider", 1),
    ("band-corruption", "case translatedBand", 1),
    ("pill-corruption", "case translatedPill", 1),
    ("primary-corruption", "case translatedPrimaryControl", 1),
    ("four-device-pixel-translation", "let devicePixelTranslation = 4", 1),
)

EXPECTED_REPAIR_NAMED_TESTS = (
    "testOffscreenQuickControlsUseFullRectangularTargetsWithCircularPaint",
    "testOffscreenProbeDoesNotOrderOrLeakApplicationWindows",
    "testOffscreenRootDispatchesEveryControlResizeAndTitleRouteAcrossTiers",
    "testOffscreenSettingsPressShowsExistingControllerExactlyOnceWithoutActivation",
    "testOffscreenLockedChromeLeavesSemanticsAndReaderStateUnchanged",
    "testDefaultUnlockedOffscreenHeaderOffersLockTeleprompter",
    "testPlaybackTargetsRespectExistingPresentationEligibility",
)
EXPECTED_REPAIR_SOURCE_MARKERS = (
    ("rectangular-hit-shape", "PrivatePresenterApp/Overlay/OverlayQuickControlsView.swift", ".contentShape(Rectangle())", 1),
    ("circular-paint", "PrivatePresenterApp/Overlay/OverlayQuickControlsView.swift", "Circle().fill(fill(configuration:", 1),
    ("offscreen-probe", "PrivatePresenterAppTests/M6VisualTestSupport.swift", "final class OffscreenRootProbe", 1),
    ("offscreen-hit-testing", "PrivatePresenterAppTests/M6VisualTestSupport.swift", "hosting.hitTest(point)", 1),
    ("product-hit-routing", "PrivatePresenterAppTests/M6VisualTestSupport.swift", "OverlayHitRegionResolver(metrics: metrics).resolve(point: point)", 1),
    ("manifest-semantics", "PrivatePresenterAppTests/M6VisualTestSupport.swift", "PresenterAccessibility.entry(", 1),
    ("windowless-model-seam", "PrivatePresenterApp/App/AppModel.swift", "testConfigurationSnapshot: OverlayConfigurationSnapshot", 2),
    ("resize-callback", "PrivatePresenterAppTests/M6VisualTestSupport.swift", "resizeChanges.append(change)", 1),
    ("title-callback", "PrivatePresenterAppTests/M6VisualTestSupport.swift", "titleChanges.append(translation)", 1),
    ("window-isolation-regression", "PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift", "testOffscreenProbeDoesNotOrderOrLeakApplicationWindows", 1),
    ("controller-playback-policy", "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift", "let playbackPresentation = ControllerPresentation(", 1),
    ("playing-pause-eligible", "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift", "state.isPlaying || playbackPresentation.isEnabled(.start)", 1),
    ("disabled-visual", "PrivatePresenterApp/Overlay/OverlayQuickControlsView.swift", ".opacity(accessibility.isEnabled ? 1 : 0.45)", 1),
    ("unlocked-label-expectation", "PrivatePresenterAppTests/PresenterAccessibilityTests.swift", 'Set(["Start scrolling", "Lock teleprompter", "Show Controller"])', 1),
)
EXPECTED_REPAIR_FORBIDDEN_MARKERS = (
    ("circular-hit-shape", "PrivatePresenterApp/Overlay/OverlayQuickControlsView.swift", ".contentShape(Circle())"),
    ("globally-ordered-test-window", "PrivatePresenterAppTests/M6VisualTestSupport.swift", "orderFrontRegardless()"),
    ("shared-test-window", "PrivatePresenterAppTests/M6VisualTestSupport.swift", "NSWindow("),
    ("stale-ax-query", "PrivatePresenterAppTests/M6VisualTestSupport.swift", "accessibilityChildren()"),
    ("duplicated-empty-policy", "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift", "state.scriptText.trimmingCharacters"),
)

EXPECTED_BAND_REPAIR_NAMED_TESTS = (
    "testCompactActiveBandUsesReservedReadingRectMidpoint",
    "testAttachedAttributeReconciliationRefreshesCachedBandWithoutReaderMutation",
    "testClipOriginRefreshUsesExactCachedTargetAndCoalescesAtLineBoundaries",
    "testCachedBandSelectionPreservesSortedMetricsAndFollowingTieBreakWithoutResort",
)
EXPECTED_BAND_REPAIR_SOURCE_MARKERS = (
    ("attribute-invalidates-band-cache", "PrivatePresenterApp/Overlay/ReaderTextSystem.swift", "viewportAdapter?.invalidateActiveBandLineMetrics()", 1),
    ("attribute-refresh-entry", "PrivatePresenterApp/Overlay/ReaderTextSystem.swift", "func refreshActiveBandAfterAttributeChange()", 1),
    ("attribute-refresh-delegation", "PrivatePresenterApp/Overlay/ReaderTextSystem.swift", "viewportAdapter?.refreshActiveBandAfterAttributeChange()", 1),
    ("effect-refresh-after-reconcile", "PrivatePresenterApp/App/DependencyContainer.swift", "readerTextSystem.refreshActiveBandAfterAttributeChange()", 1),
    ("band-cache-current-flag", "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift", "private var activeBandLineMetricsAreCurrent = false", 1),
    ("band-cache-invalidation", "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift", "func invalidateActiveBandLineMetrics()", 1),
    ("band-attribute-reconciliation", "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift", "func refreshActiveBandAfterAttributeChange()", 1),
    ("cached-evidence-view", "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift", "var cachedLineFragmentEvidence: [LineFragmentEvidence]", 1),
    ("clip-cache-refresh", "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift", "refreshActiveBandLayoutFromCachedMetrics()", 1),
    ("forced-attribute-band-refresh", "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift", "refreshActiveBandLayoutFromCachedMetrics(force: true)", 1),
    ("cache-only-band-refresh", "PrivatePresenterApp/Overlay/ReaderTextView.swift", "func refreshActiveBandLayoutFromCachedMetrics(force: Bool = false)", 1),
    ("selected-pair-coalescing", "PrivatePresenterApp/Overlay/ReaderTextView.swift", "guard force || signature != resolvedBandSignature else { return }", 1),
    ("legacy-reserved-rect-test", "PrivatePresenterAppTests/ScrollSessionControllerTests.swift", "func testBandUsesPersistedViewportFractionInsideReservedReadingRect()", 1),
)

EXPECTED_ORACLE_REPAIR_NAMED_TESTS = (
    "testActualRenderBufferUsesNamedSRGBEightBitPremultipliedRGBA",
    "testOffscreenTextKitRenderHostUsesAssertedTwoXBackingScale",
    "testSemanticOracleBandUsesTwoIndependentlyMeasuredTextKitFragmentHeights",
    "testCanonicalFrameworkMaskStaysLiteralIndependentAndMutationSensitive",
)
EXPECTED_ORACLE_REPAIR_SOURCE_MARKERS = (
    ("premultiplied-bitmap", "bitmapFormat: []", 1),
    ("explicit-eight-bit-components", "bitsPerSample: 8", 1),
    ("named-srgb-bitmap", "colorSpaceName: .deviceRGB", 1),
    ("explicit-host-layer", "hosting.wantsLayer = true", 1),
    ("explicit-host-scale", "hosting.layer?.contentsScale = backingScale", 1),
    ("asserted-effective-scale", "guard effectiveBackingScale == backingScale else", 1),
    ("textkit-scale", "textView.layer?.contentsScale = backingScale", 1),
    (
        "measured-fragment-entry",
        "static func measureSyntheticTextKitFragmentHeights() throws -> [CGFloat]",
        1,
    ),
    (
        "oracle-fragment-input",
        "static func makeCanonicalSemanticOracle(\n        fragmentHeights: [CGFloat]",
        1,
    ),
    (
        "two-measured-heights-plus-padding",
        "bandFragmentHeights[0] + bandFragmentHeights[1] + 12",
        1,
    ),
    ("literal-bounds", "let literalBounds = CGRect(origin: .zero, size: size)", 1),
    (
        "framework-continuous-literal-mask",
        "RoundedRectangle(cornerRadius: 30, style: .continuous).path(in: literalBounds).cgPath",
        1,
    ),
)
EXPECTED_ORACLE_REPAIR_FORBIDDEN_MARKERS = (
    ("nonpremultiplied-alpha", ".alphaNonpremultiplied"),
    ("screen-dependent-scale", "NSScreen"),
    ("fixed-band-formula", "2 * (42 * 1.42) + 12"),
)

EXPECTED_HOSTED_EVIDENCE_REPAIR_NAMED_TESTS = (
    "testOffscreenQuickControlsUseFullRectangularTargetsWithCircularPaint",
    "testOffscreenProbeConfirmsPrivatePresenterBeforePlaybackMutation",
    "testOffscreenLockedChromeLeavesSemanticsAndReaderStateUnchanged",
)
EXPECTED_HOSTED_EVIDENCE_REPAIR_SOURCE_MARKERS = (
    (
        "real-inventory-command",
        ".displayInventoryLoaded(RuntimeDisplayInventory(displays: [display]))",
        1,
    ),
    ("real-confirm-command", "model.send(.confirmSelectedDisplay)", 1),
    (
        "real-shielded-move-completion",
        "model.send(.completeShieldedMove(screenID: display.id))",
        1,
    ),
    ("real-show-command", "model.send(.showOverlay)", 1),
    ("eligible-playback-command", "model.send(.togglePlayback)", 2),
    (
        "offscreen-hit-identifier",
        "func offscreenIdentifier(at point: CGPoint) -> String?",
        1,
    ),
    (
        "product-hit-resolver",
        "OverlayHitRegionResolver(metrics: metrics).resolve(point: point)",
        1,
    ),
    ("manifest-control", "func semanticControl(identifier: String)", 1),
    ("active-band-frame-evidence", "activeBandFrame: system.activeBandView.frame", 2),
    (
        "text-container-inset-evidence",
        "textContainerInset: system.textView.textContainerInset",
        2,
    ),
    ("offscreen-frame-evidence", "offscreenFrame: hosting.frame", 1),
)
EXPECTED_HOSTED_EVIDENCE_REPAIR_FORBIDDEN_MARKERS = (
    ("fabricated-shield-state", "model.isShielded ="),
    ("fabricated-confirmation-state", "model.isSelectionConfirmed ="),
    ("globally-visible-window", "orderFrontRegardless()"),
    ("shared-app-window", "NSWindow("),
    ("stale-ax-traversal", "accessibilityChildren()"),
)

EXPECTED_M1_REQUIRED_PATHS = (
    "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
    "PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift",
)
EXPECTED_M1_NAMED_TESTS = (
    "testReferenceSurfaceUsesExactOpaqueNavyTokens",
    "testRoundedInteriorIsOpaqueOverWhiteAndBlack",
    "testNoTitleBarScrollbarGlowOrCompetingReaderFill",
)
EXPECTED_M1_SOURCE_MARKERS = (
    (
        "named-swiftui-srgb",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "Color(\n                .sRGB,\n                red: Double(red),",
    ),
    (
        "named-appkit-srgb",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "NSColor(srgbRed: red, green: green, blue: blue, alpha: opacity)",
    ),
    (
        "opaque-card-top",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "red: 52.0 / 255, green: 70.0 / 255, blue: 111.0 / 255, opacity: 1",
    ),
    (
        "opaque-card-middle",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "red: 44.0 / 255, green: 61.0 / 255, blue: 99.0 / 255, opacity: 1",
    ),
    (
        "opaque-card-bottom",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "red: 32.0 / 255, green: 43.0 / 255, blue: 75.0 / 255, opacity: 1",
    ),
    (
        "reading-text",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "red: 247.0 / 255, green: 248.0 / 255, blue: 252.0 / 255, opacity: 1",
    ),
    (
        "card-radius",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "static let cardRadius: CGFloat = 30",
    ),
    (
        "card-border-width",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "static let cardBorderWidth: CGFloat = 1",
    ),
    (
        "root-gradient",
        "PrivatePresenterApp/Overlay/OverlayRootView.swift",
        "LinearGradient(",
    ),
    (
        "continuous-card",
        "PrivatePresenterApp/Overlay/OverlayRootView.swift",
        "RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)",
    ),
    (
        "inset-card-border",
        "PrivatePresenterApp/Overlay/OverlayRootView.swift",
        ".strokeBorder(",
    ),
    (
        "background-accessibility-id",
        "PrivatePresenterApp/Overlay/OverlayRootView.swift",
        '.accessibilityIdentifier("privatePresenter.readerBackground")',
    ),
    (
        "transparent-appkit-reader",
        "PrivatePresenterApp/Overlay/ReaderTextView.swift",
        "backgroundView.layer?.backgroundColor = NSColor.clear.cgColor",
    ),
)

EXPECTED_M2_NAMED_TESTS = (
    "testReaderUsesSystemTypographyAndReferenceSpacing",
    "testPersistedWeightMapsWithoutReplacingText",
    "testActiveBandUsesTwoCachedTextKit2LineFragmentsForEveryWeightAtDefaultAndLargeSizes",
    "testBandLineSelectionUsesNearestThenAdjacentWithFollowingTieBreak",
    "testActiveBandOneAndZeroFragmentFallbacksAndCompactClampDoNotClipGlyphs",
    "testBandMetricsCreateNoSecondTextLayoutManagerOrCacheOwner",
    "testLiteralTextAndBandContrastThresholds",
)
EXPECTED_M2_SOURCE_MARKERS = (
    (
        "effect-font-weight",
        "PrivatePresenterApp/App/AppEffect.swift",
        "fontWeight: TeleprompterFontWeight,",
        1,
    ),
    (
        "model-persisted-weight",
        "PrivatePresenterApp/App/AppModel.swift",
        "fontWeight: preferences.fontWeight,",
        2,
    ),
    (
        "adapter-connect-weight",
        "PrivatePresenterApp/App/DependencyContainer.swift",
        "fontWeight: model.preferences.fontWeight,",
        1,
    ),
    (
        "reader-weight-parameter",
        "PrivatePresenterApp/Overlay/ReaderTextSystem.swift",
        "fontWeight: TeleprompterFontWeight = .regular,",
        1,
    ),
    (
        "reader-weight-map",
        "PrivatePresenterApp/Overlay/ReaderTextSystem.swift",
        "case .regular: .regular\n        case .medium: .medium\n        case .semibold: .semibold",
        1,
    ),
    (
        "reference-line-spacing",
        "PrivatePresenterApp/Overlay/ReaderTextSystem.swift",
        "paragraph.lineHeightMultiple = 1.42",
        1,
    ),
    (
        "named-reading-color",
        "PrivatePresenterApp/Overlay/ReaderTextSystem.swift",
        ".foregroundColor: OverlayVisualTokens.readingText.appKitColor",
        1,
    ),
    (
        "layout-authority",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "struct OverlayLayoutMetrics: Equatable",
        1,
    ),
    (
        "band-leading-token",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "red: 130.0 / 255, green: 160.0 / 255, blue: 213.0 / 255, opacity: 0.28",
        1,
    ),
    (
        "band-middle-token",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "red: 113.0 / 255, green: 145.0 / 255, blue: 202.0 / 255, opacity: 0.35",
        1,
    ),
    (
        "band-trailing-token",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "red: 130.0 / 255, green: 160.0 / 255, blue: 213.0 / 255, opacity: 0.20",
        1,
    ),
    (
        "band-accent-token",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "red: 190.0 / 255, green: 211.0 / 255, blue: 248.0 / 255, opacity: 0.62",
        1,
    ),
    (
        "band-radius",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "static let activeBandRadius: CGFloat = 8",
        1,
    ),
    (
        "line-measure-cap",
        "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
        "min(1_050, max(0, size.width - 2 * effectiveReadingSideInset))",
        1,
    ),
    (
        "cached-band-query",
        "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift",
        "func cachedActiveBandLineFragments(\n        viewportFraction: Double",
        1,
    ),
    (
        "pure-band-selection",
        "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift",
        "static func selectActiveBandLineFragments(",
        1,
    ),
    (
        "layout-before-band-query",
        "PrivatePresenterApp/Overlay/ReaderTextView.swift",
        "viewportAdapter.ensureLayout()\n        resolvedBandFragments = viewportAdapter.cachedActiveBandLineFragments(",
        1,
    ),
    (
        "band-fallback",
        "PrivatePresenterApp/Overlay/ReaderTextView.swift",
        "2 * fallbackLineHeight + 12",
        1,
    ),
    (
        "band-horizontal-expansion",
        "PrivatePresenterApp/Overlay/ReaderTextView.swift",
        "let bandMinX = max(0, metrics.effectiveReadingSideInset - 18)",
        1,
    ),
    (
        "band-gradient-layer",
        "PrivatePresenterApp/Overlay/ReaderTextView.swift",
        "private let gradientLayer = CAGradientLayer()",
        1,
    ),
)

EXPECTED_PENDING_CLAIMS = (
    ("accessibility-status", "docs/validation/m5-accessibility-result.md", "Status: PENDING"),
    ("accessibility-m3", "docs/validation/m5-accessibility-result.md", "M3 native evidence: PENDING"),
    ("accessibility-m4", "docs/validation/m5-accessibility-result.md", "M4 native evidence: PENDING"),
    ("accessibility-voiceover", "docs/validation/m5-accessibility-result.md", "VoiceOver: PENDING"),
    ("lifecycle-status", "docs/validation/m5-display-crash-quit-result.md", "Status: PENDING"),
    ("lifecycle-m3", "docs/validation/m5-display-crash-quit-result.md", "M3 native evidence: PENDING"),
    ("lifecycle-m4", "docs/validation/m5-display-crash-quit-result.md", "M4 native evidence: PENDING"),
    ("lifecycle-appkit", "docs/validation/m5-display-crash-quit-result.md", "AppKit/XCTest: PENDING"),
    ("performance-status", "docs/validation/performance-result.md", "Status: PENDING"),
    ("performance-m3", "docs/validation/performance-result.md", "M3 native evidence: PENDING"),
    ("performance-m4", "docs/validation/performance-result.md", "M4 native evidence: PENDING"),
    ("performance-instruments", "docs/validation/performance-result.md", "Local Instruments trace paths: PENDING"),
)

EXPECTED_M5_HANDOFF_FILES = (
    "MAC-CONTINUATION.md",
    "m5-artifacts.sha256",
    "m5-review-red-source-files.sha256",
    "m5-source-files.sha256",
    "private-presenter-m5-review-red-source.tar",
    "private-presenter-m5-source.tar",
    "private-presenter-m5-wsl.bundle",
)
EXPECTED_M5_MANIFEST_ENTRIES = (
    "MAC-CONTINUATION.md",
    "m5-source-files.sha256",
    "m5-review-red-source-files.sha256",
    "private-presenter-m5-source.tar",
    "private-presenter-m5-review-red-source.tar",
    "private-presenter-m5-wsl.bundle",
)
EXPECTED_FINAL_CHANGED_PATHS = (
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Scrolling/ReadingPositionMapper.swift",
    "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift",
    "PrivatePresenterApp/App/AppEffect.swift",
    "PrivatePresenterApp/App/AppModel.swift",
    "PrivatePresenterApp/App/DependencyContainer.swift",
    "PrivatePresenterApp/Overlay/DisplayLinkFrameClock.swift",
    "PrivatePresenterApp/Overlay/OverlayRootView.swift",
    "PrivatePresenterApp/Overlay/OverlayChromeView.swift",
    "PrivatePresenterApp/Overlay/OverlayQuickControlsView.swift",
    "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
    "PrivatePresenterApp/Overlay/ReaderTextSystem.swift",
    "PrivatePresenterApp/Overlay/ReaderTextView.swift",
    "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift",
    "PrivatePresenterApp/Overlay/ScrollSessionController.swift",
    "PrivatePresenterApp/Services/CarbonHotKeyService.swift",
    "PrivatePresenterApp/Services/PerformanceSignposter.swift",
    "PrivatePresenterAppTests/CarbonHotKeyServiceTests.swift",
    "PrivatePresenterAppTests/M5PerformanceTestSupport.swift",
    "PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift",
    "PrivatePresenterAppTests/M6VisualTestSupport.swift",
    "PrivatePresenterAppTests/PresenterAccessibilityTests.swift",
    "PrivatePresenterAppTests/ReaderTextSystemTests.swift",
    "PrivatePresenterAppTests/ScrollSessionControllerTests.swift",
    "PrivatePresenterAppTests/SystemDisplayServiceTests.swift",
    "PrivatePresenterUITests/ControllerAccessibilityUITests.swift",
    "PrivatePresenterUITests/MenuLifecycleUITests.swift",
    "Scripts/test_validate_project_structure_m3.py",
    "Scripts/test_validate_project_structure_m6.py",
    "Scripts/validate_project_structure.py",
    "Scripts/verify-wsl.sh",
    EXPECTED_RESULT_PATH,
)


class Milestone6ValidatorContractTests(unittest.TestCase):
    def assert_m6_constants(self) -> None:
        expected = {
            "M6_PLAN_COMMIT": EXPECTED_PLAN_COMMIT,
            "M6_PLAN_PARENT": EXPECTED_PLAN_PARENT,
            "M6_PLAN_PATH": EXPECTED_PLAN_PATH,
            "M6_M5_SOURCE_TREE": EXPECTED_M5_TREE,
            "M6_M5_HANDOFF_MANIFEST_SHA256": EXPECTED_M5_MANIFEST_SHA256,
            "M6_PROTECTED_PATHS": EXPECTED_PROTECTED_PATHS,
            "M6_FINAL_EVIDENCE_PATHS": EXPECTED_FINAL_EVIDENCE_PATHS,
            "M6_RESULT_PATH": EXPECTED_RESULT_PATH,
            "M6_CONTINUATION_DIR": EXPECTED_CONTINUATION_DIR,
            "M6_CONTINUATION_FILES": EXPECTED_CONTINUATION_FILES,
            "M6_ARTIFACT_MANIFEST_ENTRIES": EXPECTED_ARTIFACT_ENTRIES,
            "M6_SCREENSHOT_STATES": EXPECTED_SCREENSHOT_STATES,
            "M6_REFERENCE_HASHES": EXPECTED_REFERENCE_HASHES,
            "M6_RESULT_PENDING_FIELDS": EXPECTED_RESULT_PENDING_FIELDS,
            "M6_LEDGER_TITLES": EXPECTED_LEDGER_TITLES,
            "M6_LORE_TRAILER_KEYS": EXPECTED_LORE_TRAILER_KEYS,
            "M6_NATIVE_REPLAY_PAIR_LABELS": EXPECTED_NATIVE_REPLAY_PAIR_LABELS,
            "M6_STAGE_RECONSTRUCTION_MARKERS": EXPECTED_STAGE_RECONSTRUCTION_MARKERS,
            "M6_PRIOR_LEDGER_PAIRS": EXPECTED_PRIOR_LEDGER_PAIRS,
            "M6_FINAL_CHANGED_PATHS": EXPECTED_FINAL_CHANGED_PATHS,
            "M6_PREDECESSOR_PENDING_CLAIMS": EXPECTED_PENDING_CLAIMS,
            "M6_M5_HANDOFF_FILES": EXPECTED_M5_HANDOFF_FILES,
            "M6_M1_REQUIRED_PATHS": EXPECTED_M1_REQUIRED_PATHS,
            "M6_M1_NAMED_TESTS": EXPECTED_M1_NAMED_TESTS,
            "M6_M1_SOURCE_MARKERS": EXPECTED_M1_SOURCE_MARKERS,
            "M6_M2_NAMED_TESTS": EXPECTED_M2_NAMED_TESTS,
            "M6_M2_SOURCE_MARKERS": EXPECTED_M2_SOURCE_MARKERS,
            "M6_M3_REQUIRED_PATHS": EXPECTED_M3_REQUIRED_PATHS,
            "M6_M3_NAMED_TESTS": EXPECTED_M3_NAMED_TESTS,
            "M6_M3_SOURCE_MARKERS": EXPECTED_M3_SOURCE_MARKERS,
            "M6_M4_NAMED_TESTS": EXPECTED_M4_NAMED_TESTS,
            "M6_M4_SOURCE_MARKERS": EXPECTED_M4_SOURCE_MARKERS,
            "M6_M5_VISUAL_REQUIRED_PATHS": EXPECTED_M5_VISUAL_REQUIRED_PATHS,
            "M6_M5_VISUAL_NAMED_TESTS": EXPECTED_M5_VISUAL_NAMED_TESTS,
            "M6_M5_VISUAL_SOURCE_MARKERS": EXPECTED_M5_VISUAL_SOURCE_MARKERS,
            "M6_REPAIR_NAMED_TESTS": EXPECTED_REPAIR_NAMED_TESTS,
            "M6_REPAIR_SOURCE_MARKERS": EXPECTED_REPAIR_SOURCE_MARKERS,
            "M6_REPAIR_FORBIDDEN_MARKERS": EXPECTED_REPAIR_FORBIDDEN_MARKERS,
            "M6_BAND_REPAIR_NAMED_TESTS": EXPECTED_BAND_REPAIR_NAMED_TESTS,
            "M6_BAND_REPAIR_SOURCE_MARKERS": EXPECTED_BAND_REPAIR_SOURCE_MARKERS,
            "M6_ORACLE_REPAIR_NAMED_TESTS": EXPECTED_ORACLE_REPAIR_NAMED_TESTS,
            "M6_ORACLE_REPAIR_SOURCE_MARKERS": EXPECTED_ORACLE_REPAIR_SOURCE_MARKERS,
            "M6_ORACLE_REPAIR_FORBIDDEN_MARKERS": EXPECTED_ORACLE_REPAIR_FORBIDDEN_MARKERS,
            "M6_HOSTED_EVIDENCE_REPAIR_NAMED_TESTS": EXPECTED_HOSTED_EVIDENCE_REPAIR_NAMED_TESTS,
            "M6_HOSTED_EVIDENCE_REPAIR_SOURCE_MARKERS": EXPECTED_HOSTED_EVIDENCE_REPAIR_SOURCE_MARKERS,
            "M6_HOSTED_EVIDENCE_REPAIR_FORBIDDEN_MARKERS": EXPECTED_HOSTED_EVIDENCE_REPAIR_FORBIDDEN_MARKERS,
        }
        for name, value in expected.items():
            with self.subTest(constant=name):
                self.assertTrue(hasattr(VALIDATOR, name), f"missing {name}")
                actual = getattr(VALIDATOR, name)
                self.assertEqual(tuple(actual) if isinstance(value, tuple) else actual, value)

    def testM5EpochRequiresVerifiedImmutableHandoffBeforeAndAfterCopy(self) -> None:
        handoff = ROOT / ".omx/handoff/private-presenter-m5"
        actual_files = tuple(sorted(path.name for path in handoff.iterdir() if path.is_file()))
        self.assertEqual(actual_files, tuple(sorted(EXPECTED_M5_HANDOFF_FILES)))
        manifest = handoff / "m5-artifacts.sha256"
        self.assertEqual(hashlib.sha256(manifest.read_bytes()).hexdigest(), EXPECTED_M5_MANIFEST_SHA256)
        entries: list[str] = []
        for line in manifest.read_text(encoding="utf-8").splitlines():
            match = re.fullmatch(r"([0-9a-f]{64})  ([^\r\n]+)", line)
            self.assertIsNotNone(match, line)
            assert match is not None
            digest, relative = match.groups()
            entries.append(relative)
            self.assertEqual(hashlib.sha256((handoff / relative).read_bytes()).hexdigest(), digest)
        self.assertEqual(tuple(entries), EXPECTED_M5_MANIFEST_ENTRIES)
        bundle = subprocess.run(
            ["git", "bundle", "verify", "private-presenter-m5-wsl.bundle"],
            cwd=handoff,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertEqual(bundle.returncode, 0, bundle.stdout + bundle.stderr)

        runner = VALIDATOR.read("Scripts/verify-wsl.sh")
        required = (
            'M5_HANDOFF="$PWD/.omx/handoff/private-presenter-m5"',
            f"M5_MANIFEST_SHA={EXPECTED_M5_MANIFEST_SHA256}",
            'find "$M5_HANDOFF" -maxdepth 1 -type f',
            'sha256sum "$M5_HANDOFF/m5-artifacts.sha256"',
            'cp -a "$M5_HANDOFF" "$M5_ROOT/tree/.omx/handoff/private-presenter-m5"',
            'git worktree add --detach "$M5_ROOT/tree" ' + EXPECTED_PLAN_PARENT,
            EXPECTED_M5_TREE,
            "trap 'git worktree remove --force",
        )
        for marker in required:
            with self.subTest(runner_marker=marker):
                self.assertIn(marker, runner)
        self.assertEqual(runner.count("sha256sum -c m5-artifacts.sha256"), 2)
        self.assertEqual(runner.count("git bundle verify private-presenter-m5-wsl.bundle"), 2)
        start = runner.find('M5_EXPECTED_FILES="$(printf')
        end = runner.find('test "$(find', start)
        self.assertGreaterEqual(start, 0)
        self.assertGreater(end, start)
        for name in EXPECTED_M5_HANDOFF_FILES:
            self.assertEqual(runner[start:end].count(name), 1, name)

    def testVerifyWSLRunsM5OnlyInExactPreparedEpoch(self) -> None:
        runner = VALIDATOR.read("Scripts/verify-wsl.sh")
        m5_test = "python3 -B Scripts/test_validate_project_structure_m5.py"
        m6_test = "python3 -B Scripts/test_validate_project_structure_m6.py"
        epoch_start = runner.find('(cd "$M5_ROOT/tree"')
        epoch_end = runner.find('git worktree remove --force "$M5_ROOT/tree"', epoch_start)
        self.assertEqual(runner.count(m5_test), 1)
        self.assertEqual(runner.count(m6_test), 1)
        self.assertGreaterEqual(epoch_start, 0)
        self.assertGreater(epoch_end, epoch_start)
        self.assertGreater(runner.find(m5_test), epoch_start)
        self.assertLess(runner.find(m5_test), epoch_end)
        self.assertGreater(runner.find(m6_test), epoch_end)
        self.assertEqual(runner.count("python3 Scripts/validate_project_structure.py"), 2)
        for milestone in (2, 3, 4):
            self.assertEqual(runner.count(f"Scripts/test_validate_project_structure_m{milestone}.py"), 1)

        self.assertTrue(hasattr(VALIDATOR, "validate_m6_source"), "missing validate_m6_source() is intended RED")
        self.assertNotIn("validate_m5_source", inspect.getsource(VALIDATOR.validate_m6_source))
        main_source = inspect.getsource(VALIDATOR.main)
        self.assertEqual(main_source.count("validate_m6_source()"), 1)
        self.assertNotIn("validate_m5_source()", main_source)
        self.assertIn("Milestone 6 validation failed", main_source)
        self.assertNotIn("Milestone 5 validation failed", main_source)

    def testFinalM6InventoryProtectedBytesAndPendingPredecessorsAreExact(self) -> None:
        parent = VALIDATOR.git("rev-parse", f"{EXPECTED_PLAN_COMMIT}^")
        self.assertEqual(parent.returncode, 0, parent.stderr)
        self.assertEqual(parent.stdout.strip(), EXPECTED_PLAN_PARENT)
        paths = VALIDATOR.git("diff-tree", "--no-commit-id", "--name-only", "-r", EXPECTED_PLAN_COMMIT)
        self.assertEqual(paths.returncode, 0, paths.stderr)
        self.assertEqual(paths.stdout.splitlines(), [EXPECTED_PLAN_PATH])
        self.assertEqual(VALIDATOR.git("merge-base", "--is-ancestor", EXPECTED_PLAN_COMMIT, "HEAD").returncode, 0)
        for path in EXPECTED_PROTECTED_PATHS:
            with self.subTest(protected=path):
                committed = subprocess.run(
                    ["git", "show", f"{EXPECTED_PLAN_COMMIT}:{path}"],
                    cwd=ROOT,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    check=False,
                )
                self.assertEqual(committed.returncode, 0, committed.stderr.decode())
                self.assertEqual(committed.stdout, (ROOT / path).read_bytes())
        for path in EXPECTED_FINAL_EVIDENCE_PATHS:
            with self.subTest(final_path=path):
                self.assertTrue((ROOT / path).is_file(), path)
        for _, path, marker in EXPECTED_PENDING_CLAIMS:
            with self.subTest(pending_path=path, marker=marker):
                self.assertEqual(VALIDATOR.read(path).splitlines().count(marker), 1)
        self.assert_m6_constants()
        self.assertTrue(hasattr(VALIDATOR, "validate_m6_source"))
        self.assertEqual(VALIDATOR.validate_m6_source(), [])

    def testFinalStageCannotRetainAnyPhaseZeroAbsenceAllowance(self) -> None:
        self.assertTrue(
            hasattr(VALIDATOR, "validate_m6_path_inventory"),
            "final source must expose its exact path-inventory oracle",
        )
        final_violations = VALIDATOR.validate_m6_path_inventory(
            required_paths=EXPECTED_FINAL_EVIDENCE_PATHS,
        )
        for path in EXPECTED_FINAL_EVIDENCE_PATHS:
            with self.subTest(final_required_path=path):
                if (ROOT / path).is_file():
                    self.assertNotIn(f"missing-path:{path}", final_violations)
                else:
                    self.assertIn(f"missing-path:{path}", final_violations)
        source = inspect.getsource(VALIDATOR.validate_m6_path_inventory).lower()
        self.assertNotIn("getenv", source)
        self.assertNotIn("environ", source)
        self.assertEqual(
            tuple(inspect.signature(VALIDATOR.validate_m6_path_inventory).parameters),
            ("required_paths",),
        )
        final_source = inspect.getsource(VALIDATOR.validate_m6_source)
        self.assertNotIn("absent_paths", final_source)
        self.assertNotIn("PHASE_ZERO", final_source)

    def testM1OpaqueReferenceSurfaceContractAndMutations(self) -> None:
        test_source = VALIDATOR.read(
            "PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift"
        )
        for name in EXPECTED_M1_NAMED_TESTS:
            with self.subTest(named_test=name):
                self.assertEqual(test_source.count(f"func {name}()"), 1)

        for label, path, marker in EXPECTED_M1_SOURCE_MARKERS:
            with self.subTest(source_marker=label):
                source = VALIDATOR.read(path)
                self.assertEqual(source.count(marker), 1, f"{path}:{label}")

                def replaced_read(candidate: str) -> str:
                    if candidate == path:
                        return source.replace(marker, f"removed-{label}", 1)
                    return VALIDATOR_READ(candidate)

                VALIDATOR_READ = VALIDATOR.read
                with patch.object(VALIDATOR, "read", side_effect=replaced_read):
                    violations = VALIDATOR.validate_m6_source()
                self.assertIn(f"visual:m1-missing-marker:{label}", violations)

        root = VALIDATOR.read("PrivatePresenterApp/Overlay/OverlayRootView.swift")
        reader = VALIDATOR.read("PrivatePresenterApp/Overlay/ReaderTextView.swift")
        panel = VALIDATOR.read("PrivatePresenterApp/Overlay/TeleprompterPanel.swift")
        self.assertNotIn("Color(red: 0.05, green: 0.06, blue: 0.09)", root)
        self.assertNotIn("red: 0.05,\n            green: 0.06", reader)
        self.assertNotIn(".shadow(", root)
        self.assertIn("hasShadow = true", panel)
        self.assertIn("isOpaque = false", panel)
        self.assertEqual(VALIDATOR.validate_m6_source(), [])

    def testM2TypographyBandAndCachedFragmentContractAndMutations(self) -> None:
        test_source = VALIDATOR.read(
            "PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift"
        )
        for name in EXPECTED_M2_NAMED_TESTS:
            with self.subTest(named_test=name):
                self.assertEqual(test_source.count(f"func {name}()"), 1)

        for label, path, marker, expected_count in EXPECTED_M2_SOURCE_MARKERS:
            with self.subTest(source_marker=label):
                source = VALIDATOR.read(path)
                self.assertEqual(source.count(marker), expected_count, f"{path}:{label}")
                original_read = VALIDATOR.read

                def replaced_read(candidate: str) -> str:
                    if candidate == path:
                        return source.replace(marker, f"removed-{label}")
                    return original_read(candidate)

                with patch.object(VALIDATOR, "read", side_effect=replaced_read):
                    violations = VALIDATOR.validate_m6_source()
                self.assertIn(f"visual:m2-missing-marker:{label}", violations)

        adapter = VALIDATOR.read(
            "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift"
        )
        query = adapter.split("func cachedActiveBandLineFragments", 1)[1][:1_200]
        self.assertNotIn("ensureLayout(", query)
        self.assertNotIn("NSTextLayoutManager(", query)
        self.assertEqual(VALIDATOR.validate_m6_source(), [])

    def testM3ReferenceChromeInteractionAccessibilityAndFocusContract(self) -> None:
        test_source = VALIDATOR.read(
            "PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift"
        )
        for name in EXPECTED_M3_NAMED_TESTS:
            with self.subTest(named_test=name):
                self.assertEqual(test_source.count(f"func {name}()"), 1)

        for label, path, marker, expected_count in EXPECTED_M3_SOURCE_MARKERS:
            with self.subTest(source_marker=label):
                source = VALIDATOR.read(path)
                self.assertEqual(source.count(marker), expected_count, f"{path}:{label}")
                original_read = VALIDATOR.read

                def replaced_read(candidate: str) -> str:
                    if candidate == path:
                        return source.replace(marker, f"removed-{label}")
                    return original_read(candidate)

                with patch.object(VALIDATOR, "read", side_effect=replaced_read):
                    violations = VALIDATOR.validate_m6_source()
                self.assertIn(f"visual:m3-missing-marker:{label}", violations)

        chrome = VALIDATOR.read("PrivatePresenterApp/Overlay/OverlayChromeView.swift")
        root = VALIDATOR.read("PrivatePresenterApp/Overlay/OverlayRootView.swift")
        self.assertNotIn("privatePresenter.overlayVisibility", chrome)
        self.assertNotIn("if isChromeVisible", root)
        self.assertNotIn("NSApp.activate", chrome)
        self.assertNotIn("makeKeyAndOrderFront", chrome)
        self.assertEqual(VALIDATOR.validate_m6_source(), [])

    def testM4ResponsiveContainmentHitRoutingAndAnchorContract(self) -> None:
        test_source = VALIDATOR.read(
            "PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift"
        )
        for name in EXPECTED_M4_NAMED_TESTS:
            with self.subTest(named_test=name):
                self.assertEqual(test_source.count(f"func {name}()"), 1)

        for label, path, marker, expected_count in EXPECTED_M4_SOURCE_MARKERS:
            with self.subTest(source_marker=label):
                source = VALIDATOR.read(path)
                self.assertEqual(source.count(marker), expected_count, f"{path}:{label}")
                original_read = VALIDATOR.read

                def replaced_read(candidate: str) -> str:
                    if candidate == path:
                        return source.replace(marker, f"removed-{label}")
                    return original_read(candidate)

                with patch.object(VALIDATOR, "read", side_effect=replaced_read):
                    violations = VALIDATOR.validate_m6_source()
                self.assertIn(f"visual:m4-missing-marker:{label}", violations)

        resolver = VALIDATOR.read("PrivatePresenterApp/Overlay/OverlayRootView.swift")
        control = resolver.index("for region in metrics.controlRegions")
        corner = resolver.index("for region in metrics.cornerResizeRegions")
        edge = resolver.index("for region in metrics.edgeResizeRegions")
        title = resolver.index("if Self.contains(point, in: metrics.titleDragFrame)")
        self.assertLess(control, corner)
        self.assertLess(corner, edge)
        self.assertLess(edge, title)
        self.assertNotIn(".aspectRatio(", resolver)
        self.assertNotIn(".fixedSize(", resolver)
        self.assertEqual(VALIDATOR.validate_m6_source(), [])

    def testM5SemanticNativeBaselineAndMutationContract(self) -> None:
        test_source = VALIDATOR.read(
            "PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift"
        )
        for name in EXPECTED_M5_VISUAL_NAMED_TESTS:
            with self.subTest(named_test=name):
                self.assertEqual(test_source.count(f"func {name}()"), 1)

        for path in EXPECTED_M5_VISUAL_REQUIRED_PATHS:
            with self.subTest(required_path=path):
                self.assertTrue((ROOT / path).is_file(), path)

        support_path = EXPECTED_M5_VISUAL_REQUIRED_PATHS[0]
        if not (ROOT / support_path).is_file():
            return
        support = VALIDATOR.read(support_path)
        oracle_support = support.split("static func makeCanonicalSemanticOracle", 1)[-1]
        self.assertNotIn("OverlayVisualTokens", oracle_support)
        self.assertNotIn("OverlayLayoutMetrics", oracle_support)
        for forbidden in (
            "WKWebView", "HTML", "CGWindowListCreateImage",
            "SCScreenshotManager", "recordBaseline", "golden",
        ):
            self.assertNotIn(forbidden, support)

        for label, marker, expected_count in EXPECTED_M5_VISUAL_SOURCE_MARKERS:
            with self.subTest(source_marker=label):
                self.assertEqual(support.count(marker), expected_count, label)
                original_read = VALIDATOR.read

                def replaced_read(candidate: str) -> str:
                    if candidate == support_path:
                        return support.replace(marker, f"removed-{label}")
                    return original_read(candidate)

                with patch.object(VALIDATOR, "read", side_effect=replaced_read):
                    violations = VALIDATOR.validate_m6_source()
                self.assertIn(f"visual:m5-missing-marker:{label}", violations)

        self.assertEqual(VALIDATOR.validate_m6_source(), [])

    def testM6HostedSemanticRepairContractAndMutations(self) -> None:
        test_source = VALIDATOR.read(
            "PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift"
        )
        for name in EXPECTED_REPAIR_NAMED_TESTS:
            with self.subTest(named_test=name):
                self.assertEqual(test_source.count(f"func {name}()"), 1)

        for label, path, marker, expected_count in EXPECTED_REPAIR_SOURCE_MARKERS:
            with self.subTest(source_marker=label):
                source = VALIDATOR.read(path)
                self.assertEqual(source.count(marker), expected_count, f"{path}:{label}")
                original_read = VALIDATOR.read

                def replaced_read(candidate: str) -> str:
                    if candidate == path:
                        return source.replace(marker, f"removed-{label}")
                    return original_read(candidate)

                with patch.object(VALIDATOR, "read", side_effect=replaced_read):
                    violations = VALIDATOR.validate_m6_source()
                self.assertIn(f"visual:repair-missing-marker:{label}", violations)

        for label, path, marker in EXPECTED_REPAIR_FORBIDDEN_MARKERS:
            with self.subTest(forbidden_marker=label):
                source = VALIDATOR.read(path)
                self.assertNotIn(marker, source, f"{path}:{label}")
                original_read = VALIDATOR.read

                def injected_read(candidate: str) -> str:
                    if candidate == path:
                        return source + "\n" + marker
                    return original_read(candidate)

                with patch.object(VALIDATOR, "read", side_effect=injected_read):
                    violations = VALIDATOR.validate_m6_source()
                self.assertIn(f"visual:repair-forbidden:{label}", violations)

        self.assertEqual(VALIDATOR.validate_m6_source(), [])

    def testM6ActiveBandCacheRepairContractAndMutations(self) -> None:
        test_source = VALIDATOR.read(
            "PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift"
        )
        for name in EXPECTED_BAND_REPAIR_NAMED_TESTS:
            with self.subTest(named_test=name):
                self.assertEqual(test_source.count(f"func {name}()"), 1)

        for label, path, marker, expected_count in EXPECTED_BAND_REPAIR_SOURCE_MARKERS:
            with self.subTest(source_marker=label):
                source = VALIDATOR.read(path)
                self.assertEqual(source.count(marker), expected_count, f"{path}:{label}")
                original_read = VALIDATOR.read

                def replaced_read(candidate: str) -> str:
                    if candidate == path:
                        return source.replace(marker, f"removed-{label}")
                    return original_read(candidate)

                with patch.object(VALIDATOR, "read", side_effect=replaced_read):
                    violations = VALIDATOR.validate_m6_source()
                self.assertIn(
                    f"visual:band-repair-missing-marker:{label}", violations
                )

        adapter_path = "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift"
        adapter = VALIDATOR.read(adapter_path)
        selection = adapter.split(
            "static func selectActiveBandLineFragments", 1
        )[-1].split("func captureAnchor", 1)[0]
        self.assertNotIn(".sorted", selection)
        original_read = VALIDATOR.read

        def selection_resort(candidate: str) -> str:
            if candidate == adapter_path:
                return adapter.replace(
                    "let candidates = fragments",
                    "let candidates = fragments.sorted { $0.frame.minY < $1.frame.minY }",
                    1,
                )
            return original_read(candidate)

        with patch.object(VALIDATOR, "read", side_effect=selection_resort):
            self.assertIn(
                "visual:band-repair-selection-resort",
                VALIDATOR.validate_m6_source(),
            )

        def clip_owner_creep(candidate: str) -> str:
            if candidate == adapter_path:
                return adapter.replace(
                    "func setClipOriginY(_ offset: Double) {",
                    "func setClipOriginY(_ offset: Double) { ensureLayout()",
                    1,
                )
            return original_read(candidate)

        with patch.object(VALIDATOR, "read", side_effect=clip_owner_creep):
            self.assertIn(
                "visual:band-repair-clip-owner-creep",
                VALIDATOR.validate_m6_source(),
            )

        container_path = "PrivatePresenterApp/Overlay/ReaderTextView.swift"
        container = VALIDATOR.read(container_path)

        def cache_owner_creep(candidate: str) -> str:
            if candidate == container_path:
                return container.replace(
                    "func refreshActiveBandLayoutFromCachedMetrics(force: Bool = false) {",
                    "func refreshActiveBandLayoutFromCachedMetrics(force: Bool = false) { viewportAdapter.ensureLayout()",
                    1,
                )
            return original_read(candidate)

        with patch.object(VALIDATOR, "read", side_effect=cache_owner_creep):
            self.assertIn(
                "visual:band-repair-cache-owner-creep",
                VALIDATOR.validate_m6_source(),
            )

        self.assertEqual(VALIDATOR.validate_m6_source(), [])

    def testM6HostedEvidenceRepairContractAndMutations(self) -> None:
        test_source = VALIDATOR.read(
            "PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift"
        )
        for name in EXPECTED_HOSTED_EVIDENCE_REPAIR_NAMED_TESTS:
            with self.subTest(named_test=name):
                self.assertEqual(test_source.count(f"func {name}()"), 1)

        support_path = "PrivatePresenterAppTests/M6VisualTestSupport.swift"
        support = VALIDATOR.read(support_path)
        for label, marker, expected_count in EXPECTED_HOSTED_EVIDENCE_REPAIR_SOURCE_MARKERS:
            with self.subTest(source_marker=label):
                self.assertEqual(support.count(marker), expected_count, label)
                original_read = VALIDATOR.read

                def replaced_read(candidate: str) -> str:
                    if candidate == support_path:
                        return support.replace(marker, f"removed-{label}")
                    return original_read(candidate)

                with patch.object(VALIDATOR, "read", side_effect=replaced_read):
                    violations = VALIDATOR.validate_m6_source()
                self.assertIn(
                    f"visual:hosted-evidence-repair-missing-marker:{label}",
                    violations,
                )

        for label, marker in EXPECTED_HOSTED_EVIDENCE_REPAIR_FORBIDDEN_MARKERS:
            with self.subTest(forbidden_marker=label):
                self.assertNotIn(marker, support, label)
                original_read = VALIDATOR.read

                def injected_read(candidate: str) -> str:
                    if candidate == support_path:
                        return support + "\n" + marker
                    return original_read(candidate)

                with patch.object(VALIDATOR, "read", side_effect=injected_read):
                    violations = VALIDATOR.validate_m6_source()
                self.assertIn(
                    f"visual:hosted-evidence-repair-forbidden:{label}",
                    violations,
                )

        self.assertEqual(VALIDATOR.validate_m6_source(), [])

    def testM6DeterministicSemanticOracleRepairContractAndMutations(self) -> None:
        test_source = VALIDATOR.read(
            "PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift"
        )
        for name in EXPECTED_ORACLE_REPAIR_NAMED_TESTS:
            with self.subTest(named_test=name):
                self.assertEqual(test_source.count(f"func {name}()"), 1)

        support_path = "PrivatePresenterAppTests/M6VisualTestSupport.swift"
        support = VALIDATOR.read(support_path)
        for label, marker, expected_count in EXPECTED_ORACLE_REPAIR_SOURCE_MARKERS:
            with self.subTest(source_marker=label):
                self.assertEqual(support.count(marker), expected_count, label)
                original_read = VALIDATOR.read

                def replaced_read(candidate: str) -> str:
                    if candidate == support_path:
                        return support.replace(marker, f"removed-{label}")
                    return original_read(candidate)

                with patch.object(VALIDATOR, "read", side_effect=replaced_read):
                    violations = VALIDATOR.validate_m6_source()
                self.assertIn(
                    f"visual:oracle-repair-missing-marker:{label}", violations
                )

        for label, marker in EXPECTED_ORACLE_REPAIR_FORBIDDEN_MARKERS:
            with self.subTest(forbidden_marker=label):
                self.assertNotIn(marker, support, label)
                original_read = VALIDATOR.read

                def injected_read(candidate: str) -> str:
                    if candidate == support_path:
                        return support + "\n" + marker
                    return original_read(candidate)

                with patch.object(VALIDATOR, "read", side_effect=injected_read):
                    violations = VALIDATOR.validate_m6_source()
                self.assertIn(
                    f"visual:oracle-repair-forbidden:{label}", violations
                )

        mask_source = support.split(
            "private static func makeLiteralCardMask", 1
        )[-1].split("private static func drawLiteralSurface", 1)[0]
        self.assertIn(
            "RoundedRectangle(cornerRadius: 30, style: .continuous)"
            ".path(in: literalBounds).cgPath",
            mask_source,
        )
        for marker in ("CGPath(roundedRect:", "addArc(", "addCurve("):
            self.assertNotIn(marker, mask_source)

        original_read = VALIDATOR.read

        def hand_coded_mask(candidate: str) -> str:
            if candidate == support_path:
                return support.replace(
                    "private static func drawLiteralSurface",
                    "// CGPath(roundedRect: hand-coded mask\n"
                    "private static func drawLiteralSurface",
                    1,
                )
            return original_read(candidate)

        with patch.object(VALIDATOR, "read", side_effect=hand_coded_mask):
            self.assertIn(
                "visual:oracle-repair-hand-coded-mask",
                VALIDATOR.validate_m6_source(),
            )

        self.assertEqual(VALIDATOR.validate_m6_source(), [])

    def testM6PendingScreenshotIdentityRowsRejectEveryOmission(self) -> None:
        path = ROOT / EXPECTED_RESULT_PATH
        self.assertTrue(path.is_file(), "6A RED requires the additive visual-result template")
        text = path.read_text(encoding="utf-8")
        self.assertEqual(VALIDATOR.validate_m6_result_text(text), [])
        rows = VALIDATOR.m6_expected_screenshot_rows()
        self.assertEqual(len(rows), 5)

        def replace_cell(row: str, cell_index: int, value: str) -> str:
            cells = [cell.strip() for cell in row.strip("|").split("|")]
            cells[cell_index] = value
            return "| " + " | ".join(cells) + " |"

        for state, row in zip(EXPECTED_SCREENSHOT_STATES, rows, strict=True):
            for field, index in (
                ("state", 0),
                ("screenshot-hash", 1),
                ("source-sha", 2),
                ("executable-hash", 3),
                ("primary-reference-hash", 4),
                ("concept-reference-hash", 5),
            ):
                with self.subTest(state=state, omitted=field):
                    mutation = text.replace(row, replace_cell(row, index, "OMITTED"), 1)
                    violations = VALIDATOR.validate_m6_result_text(mutation)
                    self.assertTrue(
                        any(item.startswith("evidence:screenshot-row:") for item in violations),
                        violations,
                    )

    def testM6PerReferenceScoreReviewerRationaleCannotBeAveragedOrPromoted(self) -> None:
        path = ROOT / EXPECTED_RESULT_PATH
        self.assertTrue(path.is_file(), "6A RED requires the additive visual-result template")
        text = path.read_text(encoding="utf-8")
        rows = VALIDATOR.m6_expected_review_rows()
        self.assertEqual(len(rows), 10)
        for row in rows:
            cells = [cell.strip() for cell in row.strip("|").split("|")]
            for field_index, field in ((2, "score"), (3, "reviewer"), (4, "rationale")):
                with self.subTest(state=cells[0], reference=cells[1], omitted=field):
                    mutated_cells = list(cells)
                    mutated_cells[field_index] = "OMITTED"
                    replacement = "| " + " | ".join(mutated_cells) + " |"
                    violations = VALIDATOR.validate_m6_result_text(
                        text.replace(row, replacement, 1)
                    )
                    self.assertIn(
                        f"evidence:review-row:{cells[0]}:{cells[1]}", violations
                    )
        first = rows[0]
        below_threshold = first.replace(
            "| PENDING | PENDING | PENDING | PENDING |",
            "| 89 | reviewer-1 | rationale | PENDING |",
        )
        averaged = text.replace(first, below_threshold, 1) + "\nAverage score: 95/100\n"
        violations = VALIDATOR.validate_m6_result_text(averaged)
        self.assertTrue(any(item.startswith("evidence:review-") for item in violations))
        self.assertIn(
            "Averages are forbidden and cannot mask any individual score below 90/100.",
            text.splitlines(),
        )

    def testM6EveryNativeVisualPhysicalFieldStaysPendingAndPrivateNeutral(self) -> None:
        path = ROOT / EXPECTED_RESULT_PATH
        self.assertTrue(path.is_file(), "6A RED requires the additive visual-result template")
        text = path.read_text(encoding="utf-8")
        for marker in EXPECTED_RESULT_PENDING_FIELDS:
            with self.subTest(pending_marker=marker):
                mutation = text.replace(marker, marker.replace("PENDING", "PASS"), 1)
                violations = VALIDATOR.validate_m6_result_text(mutation)
                self.assertTrue(
                    any(
                        item.startswith("evidence:visual-result-pending:")
                        or item.startswith("evidence:overclaim:")
                        for item in violations
                    ),
                    violations,
                )
        for marker in (
            "SENTINEL_PRIVATE_SCRIPT",
            "document.title",
            "displayID",
            "/Users/private/operator.png",
        ):
            with self.subTest(private_marker=marker):
                violations = VALIDATOR.validate_m6_result_text(text + f"\n{marker}\n")
                self.assertTrue(
                    any(item.startswith("evidence:private-surface:") for item in violations)
                )

    def testM6NativeCompileRepairUsesParserSafeOptionalAndExplicitReturn(self) -> None:
        source = VALIDATOR.read(
            "Packages/TeleprompterCore/Sources/PromptingCore/Scrolling/ReadingPositionMapper.swift"
        )
        self.assertIn(
            "let minimumDistance = bestCandidates.map { distance($0.offset, fallbackOffset) }.min()",
            source,
        )
        self.assertIn("guard let minimumDistance else {", source)
        self.assertNotIn(
            "guard let minimumDistance = bestCandidates\n"
            "            .map { distance($0.offset, fallbackOffset) }\n"
            "            .min() else {",
            source,
        )
        invalid_start = source.index("    private static func invalidMapping(")
        invalid_end = source.index("    private static func mapping(", invalid_start)
        invalid_mapping = source[invalid_start:invalid_end]
        self.assertIn("        return mapping(\n", invalid_mapping)

    def testM6NativeSignposterImportsTheAvailableDarwinModule(self) -> None:
        source = VALIDATOR.read("PrivatePresenterApp/Services/PerformanceSignposter.swift")
        self.assertIn("import os\n", source)
        self.assertNotIn("import OS\n", source)

    def testM6ScrollTeardownUsesExplicitMainActorIsolation(self) -> None:
        source = VALIDATOR.read("PrivatePresenterApp/Overlay/ScrollSessionController.swift")
        deinit_source = source[source.index("    deinit {"):]
        self.assertIn("MainActor.assumeIsolated {", deinit_source)
        self.assertIn("clock?.invalidate()", deinit_source)
        self.assertIn(
            "performanceRegistry.end(scrollSessionInterval, outcome: .cancelled)",
            deinit_source,
        )

    def testM6AccessibilityRetryHelperReturnsEveryDecision(self) -> None:
        source = VALIDATOR.read("PrivatePresenterApp/Accessibility/PresenterAccessibility.swift")
        start = source.index("    private static func retryShortcutsVisible(")
        end = source.index("    private static func publicMenuEntry(", start)
        helper = source[start:end]
        self.assertIn("            return true\n", helper)
        self.assertIn("            return false\n", helper)
        self.assertNotIn("\n            true\n", helper)
        self.assertNotIn("\n            false\n", helper)

    def testM6CarbonIsolationReturnsCallbackAndExposesImmutableMessage(self) -> None:
        service = VALIDATOR.read("PrivatePresenterApp/Services/CarbonHotKeyService.swift")
        presentation = VALIDATOR.read("PrivatePresenterApp/Controller/ControllerPresentation.swift")
        self.assertIn("return MainActor.assumeIsolated {", service)
        self.assertIn("nonisolated static let cleanupUnknownMessage", service)
        self.assertIn("return CarbonHotKeyService.cleanupUnknownMessage", presentation)

    def testM6DisplayLinkTargetAndTeardownStayActorSafe(self) -> None:
        source = VALIDATOR.read("PrivatePresenterApp/Overlay/DisplayLinkFrameClock.swift")
        self.assertIn("    @MainActor\n    private final class Target: NSObject", source)
        self.assertIn(
            "        @objc func displayLinkDidFire(_ link: CADisplayLink) {\n"
            "            onTick(link.timestamp)\n"
            "        }",
            source,
        )
        self.assertNotIn("MainActor.assumeIsolated", source)
        self.assertNotIn("    deinit {", source)

    def testM6DenseHostedDiagnosticsUseValidInterpolationExpressions(self) -> None:
        source = VALIDATOR.read("PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift")
        self.assertIn('\\(actual ?? "nil")', source)
        self.assertIn('\\(failures.joined(separator: "; "))', source)
        self.assertNotIn('\\(actual ?? \\"nil\\")', source)
        self.assertNotIn('\\(failures.joined(separator: \\"; \\"))', source)

    def testM6UIControllerLifecycleAndFocusQueriesCompileOnXcode16(self) -> None:
        source = VALIDATOR.read("PrivatePresenterUITests/ControllerAccessibilityUITests.swift")
        self.assertIn('NSPredicate(format: "hasKeyboardFocus == true")', source)
        self.assertIn("private func assertHasKeyboardFocus(", source)
        self.assertNotIn(".hasFocus", source)

    def testM6MenuLifecycleUITestsStayOnMainActor(self) -> None:
        source = VALIDATOR.read("PrivatePresenterUITests/MenuLifecycleUITests.swift")
        self.assertIn("@MainActor\nfinal class MenuLifecycleUITests", source)

    def testM6MenuUIApplicationLaunchDoesNotCaptureNonisolatedTestCase(self) -> None:
        source = VALIDATOR.read("PrivatePresenterUITests/MenuLifecycleUITests.swift")
        self.assertIn("private lazy var app: XCUIApplication = {", source)
        self.assertIn('application.launchEnvironment["PRIVATE_PRESENTER_UI_TEST"] = "1"', source)
        self.assertNotIn("MainActor.assumeIsolated {", source)

    def testM6ControllerUITestCleanupDoesNotCaptureNonisolatedTestCase(self) -> None:
        source = VALIDATOR.read("PrivatePresenterUITests/ControllerAccessibilityUITests.swift")
        self.assertIn("private func requireSupport() throws -> M5UITestSupport", source)
        self.assertIn("defer {", source)
        self.assertIn("support?.cleanUp()", source)
        self.assertNotIn("MainActor.assumeIsolated {", source)
        self.assertNotIn("override func tearDownWithError()", source)
        self.assertNotIn("private var application:", source)

    def testM6NativeHotKeyTestsImportCarbonConstants(self) -> None:
        source = VALIDATOR.read("PrivatePresenterAppTests/CarbonHotKeyServiceTests.swift")
        self.assertIn("import Carbon\n", source)
        self.assertIn("eventNotHandledErr", source)

    def testM6NativeHotKeyStatusExpectationsUseInt32(self) -> None:
        source = VALIDATOR.read("PrivatePresenterAppTests/CarbonHotKeyServiceTests.swift")
        self.assertEqual(source.count("Int32(eventNotHandledErr)"), 2)
        self.assertNotIn("\n            eventNotHandledErr\n", source)

    def testM6VisualAnchorAssertionsUseCurrentContextModel(self) -> None:
        source = VALIDATOR.read("PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift")
        self.assertIn("XCTAssertEqual(adapter.lastRestoredAnchor, baselineResizeAnchor)", source)
        self.assertIn("XCTAssertEqual(viewport.adapter.lastRestoredAnchor, anchor)", source)
        self.assertNotIn("lastRestoredAnchor?.document", source)
        self.assertNotIn("anchor.document", source)

    def testM6AccessibilityStoreFixturesAvoidNonisolatedLifecycleState(self) -> None:
        source = VALIDATOR.read("PrivatePresenterAppTests/PresenterAccessibilityTests.swift")
        self.assertEqual(source.count("let testContainer = try makeTestContainer()"), 5)
        self.assertEqual(source.count("defer { removeTestContainer(testContainer) }"), 5)
        self.assertIn("private func makeTestContainer() throws -> URL", source)
        self.assertIn("private func removeTestContainer(_ testContainer: URL)", source)
        self.assertNotIn("private var testContainer:", source)
        self.assertNotIn("override func setUpWithError()", source)
        self.assertNotIn("override func tearDownWithError()", source)

    def testM6NativeSupportFixturesUseExplicitXcode16Types(self) -> None:
        performance = VALIDATOR.read("PrivatePresenterAppTests/M5PerformanceTestSupport.swift")
        visual = VALIDATOR.read("PrivatePresenterAppTests/M6VisualTestSupport.swift")
        self.assertIn("withExtendedLifetime(syntheticEditor)", performance)
        self.assertIn("Self.chromeIdentifiers", visual)
        self.assertIn("colorSpaceName: .deviceRGB", visual)
        self.assertIn("CGFloat.greatestFiniteMagnitude", visual)
        self.assertIn("CGColorSpace(name: CGColorSpace.sRGB)", visual)
        self.assertNotIn("intersection(chromeIdentifiers)", visual)
        self.assertNotIn("colorSpaceName: .sRGB", visual)
        self.assertNotIn("height: .greatestFiniteMagnitude", visual)
        self.assertNotIn("CGColorSpace(name: .sRGB)", visual)

    def testM6FinalMarkerInventoryUsesXcode16SupportSpellings(self) -> None:
        self.assertEqual(
            VALIDATOR.M6_M5_VISUAL_SOURCE_MARKERS,
            EXPECTED_M5_VISUAL_SOURCE_MARKERS,
        )
        self.assertEqual(VALIDATOR.M6_REPAIR_SOURCE_MARKERS, EXPECTED_REPAIR_SOURCE_MARKERS)
        self.assertEqual(
            VALIDATOR.M6_ORACLE_REPAIR_SOURCE_MARKERS,
            EXPECTED_ORACLE_REPAIR_SOURCE_MARKERS,
        )

    def testM6NativeBitmapConvertsDeviceRGBStorageToSRGB(self) -> None:
        source = VALIDATOR.read("PrivatePresenterAppTests/M6VisualTestSupport.swift")
        self.assertIn("colorSpaceName: .deviceRGB", source)
        self.assertIn("guard let sourceImage = bitmap.cgImage,", source)
        self.assertIn("let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),", source)
        self.assertIn("context.draw(sourceImage, in:", source)
        self.assertIn("guard let image = context.makeImage()", source)
        self.assertNotIn("NSColorSpace.sRGB.colorSpaceName", source)

    def testM6FocusedSupportScopeRecordsBitmapConversion(self) -> None:
        source = VALIDATOR.read("PrivatePresenterAppTests/M6VisualTestSupport.swift")
        self.assertIn("colorSpaceName: .deviceRGB", source)
        self.assertNotIn("NSColorSpace.sRGB.colorSpaceName", source)
        self.assertEqual(VALIDATOR.M6_LEDGER_TITLES, EXPECTED_LEDGER_TITLES)

    def testM6ViewportReplacementDoesNotCaptureMutableLocals(self) -> None:
        source = VALIDATOR.read("PrivatePresenterAppTests/ScrollSessionControllerTests.swift")
        self.assertIn("private final class M3ViewportProviderBox", source)
        self.assertEqual(
            source.count("let viewportBox = M3ViewportProviderBox(viewport: firstViewport)"),
            2,
        )
        self.assertEqual(source.count("readerViewportProvider: { viewportBox.viewport }"), 2)
        self.assertEqual(source.count("viewportBox.viewport = replacementViewport"), 2)
        self.assertNotIn("var currentViewport = firstViewport", source)
        self.assertNotIn("readerViewportProvider: { currentViewport }", source)

    def testM6FinalNativeFixturesIsolateWindowsClocksAndAppKitAssertions(self) -> None:
        support = VALIDATOR.read("PrivatePresenterAppTests/M6VisualTestSupport.swift")
        overlay = VALIDATOR.read("PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift")
        accessibility = VALIDATOR.read("PrivatePresenterAppTests/PresenterAccessibilityTests.swift")
        scroll = VALIDATOR.read("PrivatePresenterAppTests/ScrollSessionControllerTests.swift")
        display = VALIDATOR.read("PrivatePresenterAppTests/SystemDisplayServiceTests.swift")

        self.assertNotIn("orderFrontRegardless()", support)
        self.assertNotIn("NSWindow(", support)
        self.assertNotIn("accessibilityChildren()", support)
        self.assertIn("final class OffscreenRootProbe", support)
        self.assertIn("testOffscreenProbeDoesNotOrderOrLeakApplicationWindows", overlay)
        self.assertNotIn("orderFrontRegardless()", accessibility)
        self.assertNotIn("NSWindow(", accessibility)
        self.assertIn("selectedRange().length, 0", scroll)
        self.assertIn("let expectedBandY = min(", scroll)
        self.assertIn("XCTAssertTrue(presentation.isEnabled(.focusMode))", scroll)
        self.assertIn("size: NSSize(width: 260, height: 226)", scroll)
        self.assertIn("replacementClock.fire(at: CACurrentMediaTime() + 0.1)", scroll)
        self.assertIn('"the passRetained ownership forever"', display)

    def testM6FinalScopeIncludesNativeDisplayFixture(self) -> None:
        self.assertIn(
            "PrivatePresenterAppTests/SystemDisplayServiceTests.swift",
            EXPECTED_FINAL_CHANGED_PATHS,
        )
        self.assertEqual(VALIDATOR.M6_FINAL_CHANGED_PATHS, EXPECTED_FINAL_CHANGED_PATHS)

    def testM6NativeFixturesUseDeterministicSemanticsAndValidGeometry(self) -> None:
        support = VALIDATOR.read("PrivatePresenterAppTests/M6VisualTestSupport.swift")
        accessibility = VALIDATOR.read("PrivatePresenterAppTests/PresenterAccessibilityTests.swift")
        scroll = VALIDATOR.read("PrivatePresenterAppTests/ScrollSessionControllerTests.swift")
        display_test = VALIDATOR.read("PrivatePresenterAppTests/SystemDisplayServiceTests.swift")

        self.assertIn("func semanticControl(identifier: String)", support)
        self.assertIn("OverlayHitRegionResolver(metrics: metrics)", support)
        self.assertNotIn("NSAccessibilityProtocol", support)
        self.assertNotIn("NSAccessibilityProtocol", accessibility)
        self.assertIn(
            "testOverlayChromeSemanticsMatchActualFortyFourPointLayoutFrames",
            accessibility,
        )
        self.assertIn("size: NSSize(width: 260, height: 226)", scroll)
        self.assertIn(
            "let anchor = viewport.adapter.captureAnchor(viewportFraction: 0.5)",
            scroll,
        )
        self.assertIn("replacementViewport.semanticRestoreOffset = nil", scroll)
        self.assertIn("replacementClock.fire(at: CACurrentMediaTime() + 0.1)", scroll)
        self.assertIn("XCTAssertGreaterThan(replacementViewport.clipOriginY, 270)", scroll)
        self.assertIn('"the passRetained ownership forever"', display_test)

    def testM6FinalMarkersRecordOffscreenSemanticTraversal(self) -> None:
        marker = (
            "product-hit-routing",
            "PrivatePresenterAppTests/M6VisualTestSupport.swift",
            "OverlayHitRegionResolver(metrics: metrics).resolve(point: point)",
            1,
        )
        self.assertIn(marker, EXPECTED_REPAIR_SOURCE_MARKERS)
        self.assertEqual(
            VALIDATOR.M6_REPAIR_SOURCE_MARKERS,
            EXPECTED_REPAIR_SOURCE_MARKERS,
        )

    def testM6HistoryIsExactlyImmediateRedGreenPairs(self) -> None:
        rows = VALIDATOR.m6_history_rows()
        self.assertEqual(VALIDATOR.validate_m6_history_rows(rows), [])
        self.assertEqual(len(rows), len(EXPECTED_LEDGER_TITLES) * 2)
        self.assertEqual(
            [title for _, _, title in rows],
            [title for title in EXPECTED_LEDGER_TITLES for _ in range(2)],
        )
        for index in range(len(EXPECTED_LEDGER_TITLES)):
            self.assertEqual(rows[index * 2 + 1][1], [rows[index * 2][0]])
            mutation = list(rows)
            green_sha, _, green_title = mutation[index * 2 + 1]
            mutation[index * 2 + 1] = (green_sha, [EXPECTED_PLAN_COMMIT], green_title)
            self.assertIn(
                f"ledger:nonconsecutive:{index * 2 + 1}",
                VALIDATOR.validate_m6_history_rows(mutation),
            )

    def testM6EveryIntendedLoreTrailerIsGitNativeAndContiguous(self) -> None:
        good = (
            "Auditable decision\n\nContext.\n\n"
            "Constraint: Exact history is locally preserved.\n"
            "Confidence: high\n"
            "Tested: git interpret-trailers --parse\n"
        )
        self.assertEqual(VALIDATOR.validate_m6_lore_message(good), [])
        self.assertIn(
            "noncontiguous-trailers",
            VALIDATOR.validate_m6_lore_message(
                good.replace("\nConfidence:", "\n\nConfidence:")
            ),
        )
        self.assertIn(
            "literal-newline",
            VALIDATOR.validate_m6_lore_message(good + r"\nNot-tested: native host"),
        )
        self.assertEqual(
            VALIDATOR.validate_m6_lore_history(VALIDATOR.m6_history_rows()), []
        )

    def testM6ContinuationReconstructsAndReplaysEveryExactStage(self) -> None:
        guide = (ROOT / EXPECTED_CONTINUATION_DIR / "MAC-CONTINUATION.md").read_text(
            encoding="utf-8"
        )
        for marker in EXPECTED_STAGE_RECONSTRUCTION_MARKERS:
            with self.subTest(marker=marker):
                self.assertIn(marker, guide)
        replay_rows = re.findall(
            r"^(\d+) ([0-9a-f]{40}) ([0-9a-f]{40}) (native|static)$",
            guide,
            re.MULTILINE,
        )
        rows = VALIDATOR.m6_history_rows()
        expected_pairs = [
            (rows[index][0], rows[index + 1][0])
            for index in range(0, len(rows), 2)
        ]
        self.assertEqual(
            [(red, green) for _, red, green, _ in replay_rows], expected_pairs
        )
        self.assertEqual(
            tuple(
                int(label)
                for label, _, _, replay_kind in replay_rows
                if replay_kind == "native"
            ),
            EXPECTED_NATIVE_REPLAY_PAIR_LABELS,
        )

    def testM6ContinuationInventoryHashesPairsSourceTreeTarAndBundleAreExact(self) -> None:
        handoff = ROOT / EXPECTED_CONTINUATION_DIR
        self.assertTrue(handoff.is_dir(), "6A RED requires the exact M6 Mac continuation")
        self.assertEqual(VALIDATOR.validate_m6_continuation(handoff), [])
        self.assertEqual(
            tuple(sorted(path.name for path in handoff.iterdir() if path.is_file())),
            tuple(sorted(EXPECTED_CONTINUATION_FILES)),
        )

        guide = (handoff / "MAC-CONTINUATION.md").read_text(encoding="utf-8")
        rows = VALIDATOR.m6_history_rows()
        source_sha = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip()
        source_tree = subprocess.check_output(
            ["git", "rev-parse", "HEAD^{tree}"], cwd=ROOT, text=True
        ).strip()
        self.assertEqual(
            VALIDATOR.validate_m6_continuation_guide(
                guide,
                history_rows=rows,
                source_sha=source_sha,
                source_tree=source_tree,
            ),
            [],
        )
        for label, mutation in (
            ("source", guide.replace(source_sha, "0" * 40, 1)),
            ("tree", guide.replace(source_tree, "0" * 40, 1)),
            (
                "pair",
                guide.replace(rows[1][0], rows[0][0], 1),
            ),
        ):
            with self.subTest(guide_identity=label):
                self.assertTrue(
                    VALIDATOR.validate_m6_continuation_guide(
                        mutation,
                        history_rows=rows,
                        source_sha=source_sha,
                        source_tree=source_tree,
                    )
                )

        with tempfile.TemporaryDirectory() as directory:
            scratch = Path(directory) / "handoff"
            shutil.copytree(handoff, scratch)
            (scratch / "unexpected.bin").write_bytes(b"extra")
            self.assertIn(
                "continuation:exact-file-inventory",
                VALIDATOR.validate_m6_continuation(scratch),
            )

        for name in EXPECTED_CONTINUATION_FILES:
            with self.subTest(missing_file=name), tempfile.TemporaryDirectory() as directory:
                scratch = Path(directory) / "handoff"
                shutil.copytree(handoff, scratch)
                (scratch / name).unlink()
                self.assertIn(
                    "continuation:exact-file-inventory",
                    VALIDATOR.validate_m6_continuation(scratch),
                )

        for manifest_name in ("m6-source-files.sha256", "m6-artifacts.sha256"):
            with self.subTest(duplicate_manifest=manifest_name), tempfile.TemporaryDirectory() as directory:
                scratch = Path(directory) / "handoff"
                shutil.copytree(handoff, scratch)
                manifest = scratch / manifest_name
                first = manifest.read_text(encoding="utf-8").splitlines()[0]
                manifest.write_text(
                    manifest.read_text(encoding="utf-8") + first + "\n",
                    encoding="utf-8",
                )
                self.assertIn(
                    f"continuation:manifest-duplicate:{manifest_name}",
                    VALIDATOR.validate_m6_continuation(scratch),
                )

        artifact_manifest = handoff / "m6-artifacts.sha256"
        artifact_entries, _ = VALIDATOR.parse_sha256_manifest(artifact_manifest)
        self.assertEqual(
            tuple(relative for _, relative in artifact_entries),
            EXPECTED_ARTIFACT_ENTRIES,
        )
        for _, relative in artifact_entries:
            with self.subTest(wrong_artifact_hash=relative), tempfile.TemporaryDirectory() as directory:
                scratch = Path(directory) / "handoff"
                shutil.copytree(handoff, scratch)
                manifest = scratch / "m6-artifacts.sha256"
                source = manifest.read_text(encoding="utf-8")
                manifest.write_text(
                    re.sub(
                        rf"^[0-9a-f]{{64}}  {re.escape(relative)}$",
                        f"{'0' * 64}  {relative}",
                        source,
                        count=1,
                        flags=re.MULTILINE,
                    ),
                    encoding="utf-8",
                )
                self.assertIn(
                    f"continuation:artifact-hash:{relative}",
                    VALIDATOR.validate_m6_continuation(scratch),
                )


if __name__ == "__main__":
    unittest.main()
