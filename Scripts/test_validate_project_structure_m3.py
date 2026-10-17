#!/usr/bin/env python3
"""RED/GREEN contract for the Milestone 3 structure validator."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
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

EXPECTED_PATHS = (
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Scrolling/ScrollCommand.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Scrolling/ScrollEngine.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Scrolling/ReadingPositionMapper.swift",
    "Packages/TeleprompterCore/Tests/TeleprompterCoreTests/ScrollEngineTests.swift",
    "Packages/TeleprompterCore/Tests/TeleprompterCoreTests/ReadingPositionMapperTests.swift",
    "PrivatePresenterApp/Interfaces/ReaderViewport.swift",
    "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift",
    "PrivatePresenterApp/Overlay/DisplayLinkFrameClock.swift",
    "PrivatePresenterApp/Overlay/ScrollSessionController.swift",
    "PrivatePresenterAppTests/ScrollSessionControllerTests.swift",
    "PrivatePresenterApp/App/AppCommand.swift",
    "PrivatePresenterApp/App/AppEffect.swift",
    "PrivatePresenterApp/App/AppModel.swift",
    "PrivatePresenterApp/App/DependencyContainer.swift",
    "PrivatePresenterApp/App/AppRuntime.swift",
    "PrivatePresenterApp/Controller/ControllerPresentation.swift",
    "PrivatePresenterApp/Controller/ControllerView.swift",
    "PrivatePresenterApp/Overlay/ReaderTextSystem.swift",
    "PrivatePresenterApp/Overlay/ReaderTextView.swift",
    "PrivatePresenterApp/Overlay/OverlayRootView.swift",
    "PrivatePresenterApp/Overlay/OverlayPanelController.swift",
    "PrivatePresenterAppTests/AppModelTests.swift",
    "PrivatePresenterAppTests/ControllerPresentationTests.swift",
    "PrivatePresenterAppTests/ReaderTextSystemTests.swift",
    "PrivatePresenterAppTests/OverlayPanelControllerTests.swift",
    "Scripts/test_validate_project_structure_m3.py",
    "Scripts/validate_project_structure.py",
)

CANONICAL_NAMES = (
    "testElapsedTimeNotFrameCountControlsOffset",
    "testSixtyAndOneTwentyHertzMatch",
    "testPausePreservesExactOffset",
    "testSpeedChangeDoesNotJump",
    "testEndClampsAndPauses",
    "testRestartReturnsZeroAndPauses",
    "testForwardBackwardClamp",
    "testSuspensionDoesNotJump",
    "testInsertionBeforeAnchorShiftsOffset",
    "testDeletionBeforeAnchorShiftsOffset",
    "testEditAfterAnchorDoesNotMove",
    "testOverlapClampsAndRequestsPause",
    "testEmojiOffsetsAreUTF16Safe",
    "testLayoutChangeRestoresViewportFraction",
    "testReaderHidesScrollerAndClips",
    "testMaximumOffsetAccountsForToolbarInset",
    "testBandDoesNotBecomeTextSelection",
    "testRestorePlacesAnchorAtBand",
    "testScrollTickPerformsNoTextMutation",
    "testFakeTicksDriveViewport",
    "testPauseStopsClock",
    "testHiddenPanelStopsClock",
    "testStaleGenerationCallbackIsIgnored",
    "testTickDoesNotPublishSwiftUIStatePerFrame",
    "testEndPublishesOnePausedTransition",
)

ADDED_NAMES = (
    "testStartTimestampMakesFirstTickAdvance",
    "testSpeedChangeSettlesOldSpeedBeforeInstallingNewSpeed",
    "testInvalidTimestampPausesOnceWithoutMovement",
    "testSuspensionGapPausesOnceWithoutCatchUp",
    "testUptimeClockDomainIsUsedConsistently",
    "testMaximumOffsetChangeRequiresPause",
    "testManualMoveSettlesElapsedTimeBeforeClamping",
    "testTerminalStopReasonIsEdgeTriggered",
    "testInsertionExactlyAtAnchorClampsAndRequestsPause",
    "testInvalidRangeOverflowClampsAndRequestsPause",
    "testSplitSurrogateRangeClampsAndRequestsPause",
    "testResultDocumentMismatchClampsAndRequestsPause",
    "testAnchorNormalizesBackwardToScalarBoundary",
    "testExactIndependentContextsSelectUniqueCandidate",
    "testAbsentContextClampsAndRequestsPause",
    "testAmbiguousEqualContextTieClampsAndRequestsPause",
    "testReaderLayerOrderIsBackgroundBandThenTransparentClip",
    "testBottomDocumentPaddingIsExactlySixtyFourPoints",
    "testExistingHeaderIsNotDoubleCountedInMaximumOffset",
    "testBandUsesPersistedViewportFractionInsideReservedReadingRect",
    "testBandIsNonHitTestingAndAccessibilityIgnored",
    "testIncrementalEditRestoresMappedAnchor",
    "testInsertionAtAnchorPausesAndRestoresBoundary",
    "testRevisionGapResyncIsSynchronousAndSingle",
    "testResizeRestoresAnchorAtBand",
    "testFontChangeRestoresAnchorAtBand",
    "testAlignmentChangeRestoresAnchorAtBand",
    "testThreeCompleteLinesPreferredForManualStep",
    "testManualStepFallsBackToClampedViewportFraction",
    "testClockRequiresAttachedReaderView",
    "testDisplayLinkUsesCommonModeAndTimestamp",
    "testDetachInvalidatesClockBeforeReplacement",
    "testScreenMoveInvalidatesAndRecreatesWithoutAutoResume",
    "testTeardownInvalidatesClockAndReleasesOwners",
    "testAppModelIsSoleSessionGenerationIssuer",
    "testSpeedChangeDoesNotAdvanceGeneration",
    "testPauseInvalidatesGenerationBeforeStopEffect",
    "testHideStopsAndCapturesBeforeOrderOut",
    "testPrivacyLossStopsBeforeShieldMove",
    "testClockUnavailablePublishesExactlyOnePausedTransition",
    "testOnlyAuthorizedRetiringGenerationTerminalCaptureIsAccepted",
    "testArbitraryStaleTerminalCaptureIsRejected",
    "testSemanticCheckpointsAreAtMostOncePerSecond",
    "testReaderResyncHasNoTaskYieldOrRecursiveEffectHandling",
    "testEndInvalidatesClockBeforeOnePausedTransition",
    "testControllerExposesBackAndForwardWithoutM4GlobalInput",
)


class Milestone3ValidatorContractTests(unittest.TestCase):
    def violations_with(self, replacements: dict[str, str]) -> list[str]:
        original_read = VALIDATOR.read

        def replaced_read(path: str) -> str:
            return replacements[path] if path in replacements else original_read(path)

        with patch.object(VALIDATOR, "read", side_effect=replaced_read):
            return VALIDATOR.validate_m3_source()

    def test_m3_required_path_inventory_is_exact(self) -> None:
        self.assertEqual(set(VALIDATOR.M3_REQUIRED_PATHS), set(EXPECTED_PATHS))
        self.assertEqual(len(VALIDATOR.M3_REQUIRED_PATHS), len(EXPECTED_PATHS))

    def test_all_twenty_five_canonical_names_are_enforced_exactly(self) -> None:
        self.assertEqual(tuple(VALIDATOR.M3_CANONICAL_NAMED_TESTS), CANONICAL_NAMES)
        self.assertEqual(len(set(VALIDATOR.M3_CANONICAL_NAMED_TESTS)), 25)

    def test_all_added_boundary_and_lifecycle_names_are_enforced_exactly(self) -> None:
        self.assertEqual(tuple(VALIDATOR.M3_ADDED_NAMED_TESTS), ADDED_NAMES)
        self.assertEqual(len(set(VALIDATOR.M3_ADDED_NAMED_TESTS)), len(ADDED_NAMES))
        self.assertEqual(len(ADDED_NAMES[-17:]), 17)

    def test_prohibited_m4_network_private_and_dependency_surfaces_are_enforced(self) -> None:
        for marker in (
            "NSStatusItem", "MenuBarExtra", "addGlobalMonitorForEvents",
            "addLocalMonitorForEvents", "CGEventTap", "AXIsProcessTrusted",
            "WKWebView", "URLSession", ".layoutManager",
        ):
            self.assertIn(marker, VALIDATOR.M3_PROHIBITED_PATTERNS)
        self.assertEqual(
            tuple(VALIDATOR.M3_ALLOWED_PACKAGE_DEPENDENCIES),
            ("TeleprompterCore", "Carbon.framework"),
        )

    def test_validator_rejects_duplicate_or_missing_authority_owners(self) -> None:
        path = "PrivatePresenterApp/App/AppModel.swift"
        self.assertIn(
            "authority:AppModel-count",
            self.violations_with({path: VALIDATOR.read(path) + "\nfinal class AppModel {}\n"}),
        )
        path = "PrivatePresenterApp/Overlay/OverlayPanelController.swift"
        source = VALIDATOR.read(path).replace(
            "TeleprompterPanel(contentRect:", "TeleprompterPanel_REMOVED(contentRect:"
        )
        self.assertIn("authority:panel-construction-count", self.violations_with({path: source}))
        path = "PrivatePresenterApp/App/DependencyContainer.swift"
        source = VALIDATOR.read(path).replace(
            "ScrollSessionController(", "ScrollSessionController_REMOVED("
        )
        self.assertIn(
            "authority:scroll-session-construction-count",
            self.violations_with({path: source}),
        )

    def test_validator_requires_textkit2_and_display_link_hot_path_contracts(self) -> None:
        path = "PrivatePresenterApp/Overlay/ReaderTextSystem.swift"
        source = VALIDATOR.read(path).replace(
            "NSTextLayoutManager()",
            "NSTextLayoutManager_BROKEN()",
        ) + "\n// mutation reader.layoutManager\n"
        violations = self.violations_with({path: source})
        self.assertIn("textkit:reader-not-textkit2", violations)
        self.assertTrue(any(v.startswith("prohibited:.layoutManager:") for v in violations))

        path = "PrivatePresenterApp/Overlay/DisplayLinkFrameClock.swift"
        source = VALIDATOR.read(path).replace("link.timestamp", "link.targetTimestamp")
        violations = self.violations_with({path: source})
        self.assertIn("clock:timestamp", violations)
        self.assertIn("clock:target-timestamp", violations)
        source = VALIDATOR.read(path).replace("forMode: .common", "forMode: .default")
        self.assertIn("clock:common-run-loop", self.violations_with({path: source}))

        path = "PrivatePresenterApp/Overlay/ScrollSessionController.swift"
        source = VALIDATOR.read(path) + "\n// mutation model.send(.scrollCheckpoint)\n"
        self.assertIn("hot-path:model-publication", self.violations_with({path: source}))

    def test_validator_preserves_schema_v1_and_panel_safety_defaults(self) -> None:
        path = "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/PersistedSnapshot.swift"
        source = VALIDATOR.read(path).replace(
            "static let currentSchemaVersion = 1", "static let currentSchemaVersion = 2"
        )
        self.assertIn("schema:persisted-snapshot-version", self.violations_with({path: source}))

        mutations = (
            (
                "PrivatePresenterApp/App/AppRuntime.swift",
                "proofLevel: OverlayPanelLevel = .statusBar",
                "proofLevel: OverlayPanelLevel = .floating",
                "panel:status-bar-default",
            ),
            (
                "PrivatePresenterApp/App/DependencyContainer.swift",
                "orderingMode: OverlayPanelOrderingMode = .frontRegardless",
                "orderingMode: OverlayPanelOrderingMode = .front",
                "panel:front-regardless-default",
            ),
            (
                "PrivatePresenterApp/Overlay/TeleprompterPanel.swift",
                "override var canBecomeKey: Bool { !isOverlayLocked && NSApp.isActive }",
                "override var canBecomeKey: Bool { true }",
                "panel:permanent-non-key",
            ),
            (
                "PrivatePresenterApp/Overlay/TeleprompterPanel.swift",
                "override var canBecomeMain: Bool { false }",
                "override var canBecomeMain: Bool { true }",
                "panel:permanent-non-main",
            ),
        )
        for path, old, new, expected in mutations:
            self.assertIn(expected, self.violations_with({path: VALIDATOR.read(path).replace(old, new)}))

    def test_validator_rejects_m4_network_private_api_and_dependency_mutations(self) -> None:
        path = "PrivatePresenterApp/App/AppModel.swift"
        source = VALIDATOR.read(path) + (
            "\n// NSStatusItem URLSession addGlobalMonitorForEvents CGEventTap AXIsProcessTrusted\n"
        )
        project = VALIDATOR.read("project.yml").replace("- sdk: Carbon.framework", "- sdk: Network.framework")
        violations = self.violations_with({path: source, "project.yml": project})
        for marker in (
            "NSStatusItem", "URLSession", "addGlobalMonitorForEvents",
            "CGEventTap", "AXIsProcessTrusted",
        ):
            self.assertTrue(any(v.startswith(f"prohibited:{marker}:") for v in violations))
        self.assertIn("dependency:project-yml-changed", violations)

    def test_current_m2_and_m3_source_satisfy_their_validators(self) -> None:
        self.assertEqual(VALIDATOR.validate_m2_source(), [])
        self.assertEqual(VALIDATOR.validate_m3_source(), [])


if __name__ == "__main__":
    unittest.main()
