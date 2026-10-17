#!/usr/bin/env python3
"""RED/GREEN contract for the Milestone 5 current-source validator."""

from __future__ import annotations

import importlib.util
import inspect
from pathlib import Path
import subprocess
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

EXPECTED_BASELINE = "d7e79ba1623d76a5df07d2b482bae9ea795ea3cb"

EXPECTED_PLANNED_PATHS = (
    "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift",
    "PrivatePresenterApp/Interfaces/PerformanceSignposting.swift",
    "PrivatePresenterApp/Services/PerformanceSignposter.swift",
    "PrivatePresenterAppTests/PresenterAccessibilityTests.swift",
    "PrivatePresenterAppTests/PerformanceSignposterTests.swift",
    "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
    "PrivatePresenterUITests/ControllerAccessibilityUITests.swift",
    "PrivatePresenterUITests/M5UITestSupport.swift",
    "Scripts/generate-m5-fixture.py",
    "Scripts/test_validate_project_structure_m5.py",
    "docs/validation/m5-accessibility-result.md",
    "docs/validation/m5-display-crash-quit-result.md",
    "docs/validation/performance-result.md",
)

EXPECTED_ACCESSIBILITY_TESTS = (
    "testAllIconButtonsHaveLabelsAndHelp",
    "testWarningExposesTextNotColorOnly",
    "testControllerKeyboardTraversal",
    "testFontRangeControlsAreReachable",
    "testAccessibilityManifestContainsEveryActionExactlyOnce",
    "testEveryDynamicControlExposesLabelValueHelpAndIdentifier",
    "testControllerReverseTraversalHasNoTrap",
    "testOverlayActionTargetsAreAtLeastFortyFourPoints",
    "testReaderBandAndInteractionZonesAreIgnored",
    "testWarningFocusNeverActivatesBackgroundApplication",
    "testPublicAccessibilitySurfacesNeverContainPrivateSentinels",
    "testReduceMotionChangeRemovesFadeButKeepsReadingMotion",
    "testUITestStoreOverrideRequiresDebugFlagXCTestAndTemporaryDescendant",
    "testUITestStoreOverrideRejectsDotDotTraversal",
    "testUITestStoreOverrideRejectsSymlinkEscape",
    "testUITestStoreOverrideRejectsPrefixOnlySibling",
    "testUITestStoreOverrideRejectsReleaseBuild",
    "testUITestStoreOverrideRejectsMissingXCTestConfiguration",
)

EXPECTED_LIFECYCLE_TESTS = (
    "testCrashRestoreIsPaused",
    "testDisconnectDuringTickPersistsAnchorThenHides",
    "testReconnectRequiresConfirmation",
    "testQuitTearsDownCallbacks",
    "testStaleTopologyResultCannotMoveRevealOrResume",
    "testQueuedDisplayCallbackAfterStopIsIgnored",
    "testReconnectConfirmationMustMatchCurrentGeneration",
    "testDisconnectEnqueuesCapturedAnchorBeforeOrderOutWithoutAwaitingDisk",
    "testCrashRestoreClearsRuntimeDisplayAndNeverShowsOrStarts",
    "testSuccessfulQuitUsesExactLifecycleOrder",
    "testFlushFailureTearsDownNothingAndLeavesRecoveryAvailable",
    "testOverlappingQuitRequestsShareOneAttempt",
    "testRepeatedSuccessfulTeardownIsIdempotent",
    "testQuiescentTickFocusHotKeyAndDisplayCallbacksAreIgnored",
    "testCarbonDispatchClosesBeforeUnregisterAndCleanupStatusDoesNotReopenIt",
    "testRuntimeOwnersDeallocateAfterTeardown",
)

EXPECTED_SIGNPOST_TESTS = (
    "testSignpostIntervalsBalanceForEveryTerminalPath",
    "testSignpostAPIHasNoArbitraryMetadataSurface",
    "testSignpostNamesAndClosedMetadataAreExact",
    "testSignpostPayloadsNeverContainPrivateSentinels",
    "testRestoreIntervalEndsAfterReaderLayoutAndMainActorSentinel",
    "testEditIntervalEndsAfterIncrementalReaderLayout",
    "testDebounceWaitIsOutsidePersistenceIntervals",
    "testSnapshotEncodeWriteAndFlushAreSeparateIntervals",
    "testSignpostRegistryIsEmptyAfterTeardown",
)

EXPECTED_PERFORMANCE_TESTS = (
    "testFiftyThousandWordLoad",
    "testRepeatedEditDoesNotRebuildWholeReader",
    "testDebouncedSaveDoesNotBlockMainActor",
    "testScrollTicksDoNotMutateTextOrPublishPerFrame",
    "testFixtureIsExactlyFiftyThousandWords",
    "testSwiftFixtureMatchesGeneratedBytesAndDigest",
    "testLoadMeasurementEndpointRequiresEditAndMainActorSentinel",
    "testThreeHundredEditSequenceRestoresFixtureAfterEveryPair",
    "testNearestRankP95UsesSampleTwoHundredEightyFive",
    "testEveryEditAndMainThreadStallUsesOneHundredMillisecondCeiling",
    "testScrollMemoryUsesFivePointOrdinaryLeastSquares",
    "testAbsoluteThresholdsRequireExplicitBaselineOptIn",
    "testDelayedFilesystemDoesNotBlockEditAndFinalRevisionFlushes",
)

EXPECTED_INDEPENDENT_REVIEW_NAMED_TESTS = (
    "testInProcessLoadTrialIsSemanticOnlyAndCannotProveAbsoluteBaseline",
    "testProcessFootprintCannotSubstituteForInstrumentsAllocationSamples",
    "testBenchmarkRestoreRequiresProductEditorEditReaderAndSentinelBeforeEnd",
    "testRejectedProductEditEndsRealInterval",
    "testReaderResyncEndsRealInterval",
    "testDebouncedSaveSupersessionEndsRealIntervals",
    "testProductTeardownCancelsEveryOpenInterval",
    "testTerminationDuringDelayedStartupAwaitsLoadedRevisionBeforeExactFlushAndRetry",
    "testOverlayChromeSemanticsMatchActualFortyFourPointLayoutFrames",
)

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
    "docs/validation/m0-phase-a-causal-decision-2026-07-14.md",
    "docs/validation/m0-phase-b-physical-selection-2026-07-14.md",
    "docs/validation/m2-controller-editor-display-safety-result.md",
    "docs/validation/overlay-proof-result.md",
    "docs/validation/overlay-proof-template.md",
    "docs/validation/source-artifact-checksums.sha256",
)

EXPECTED_PENDING_EVIDENCE = (
    "docs/validation/m5-accessibility-result.md",
    "docs/validation/m5-display-crash-quit-result.md",
    "docs/validation/performance-result.md",
)

EXPECTED_PROHIBITED_PATTERNS = (
    "addGlobalMonitorForEvents",
    "addLocalMonitorForEvents",
    "CGEventTap",
    "CGEvent.tapCreate",
    "AXIsProcessTrusted",
    "AXUIElement",
    "NSEvent.pressedMouseButtons",
    "CGEventSource.keyState",
    "NSApp.activate(",
    "makeKeyAndOrderFront(",
    "URLSession",
    "WKWebView",
    "MenuBarExtra",
    "Logger(",
    "os_log(",
    "MetricKit",
    "Sentry",
    "telemetry",
    "analytics",
    "LinearGradient(",
    "#34466F",
    "#202B4B",
    "#F7F8FC",
)

EXPECTED_CONTINUATION_PATHS = (
    ".omx/handoff/private-presenter-m5/MAC-CONTINUATION.md",
    ".omx/handoff/private-presenter-m5/m5-artifacts.sha256",
    ".omx/handoff/private-presenter-m5/m5-source-files.sha256",
    ".omx/handoff/private-presenter-m5/private-presenter-m5-source.tar",
    ".omx/handoff/private-presenter-m5/private-presenter-m5-wsl.bundle",
)

EXPECTED_FULL_REQUIRED_PATHS = EXPECTED_PLANNED_PATHS + (
    "PrivatePresenterAppTests/M5PerformanceTestSupport.swift",
) + EXPECTED_CONTINUATION_PATHS

EXPECTED_FIXTURE_CONTRACT_MARKERS = (
    (
        "python-word-count",
        "Scripts/generate-m5-fixture.py",
        "WORD_COUNT = 50_000",
    ),
    (
        "python-line-width",
        "Scripts/generate-m5-fixture.py",
        "LINE_WIDTH = 20",
    ),
    (
        "python-utf8-count",
        "Scripts/generate-m5-fixture.py",
        "EXPECTED_UTF8_BYTES = 499_999",
    ),
    (
        "python-utf16-count",
        "Scripts/generate-m5-fixture.py",
        "EXPECTED_UTF16_UNITS = 499_999",
    ),
    (
        "python-newline-count",
        "Scripts/generate-m5-fixture.py",
        "EXPECTED_NEWLINES = 2_499",
    ),
    (
        "python-digest",
        "Scripts/generate-m5-fixture.py",
        'EXPECTED_DIGEST = "d2aff66f0796536318d97d3b1d8080247728798dfa110725994019d58e7b09f4"',
    ),
    (
        "python-token-format",
        "Scripts/generate-m5-fixture.py",
        'f"word{index:05d}"',
    ),
    (
        "python-first-token",
        "Scripts/generate-m5-fixture.py",
        'words[0] != "word00000"',
    ),
    (
        "python-middle-token",
        "Scripts/generate-m5-fixture.py",
        'data[250_000:250_009] != b"word25000"',
    ),
    (
        "python-last-token",
        "Scripts/generate-m5-fixture.py",
        'words[-1] != "word49999"',
    ),
    (
        "python-no-final-newline",
        "Scripts/generate-m5-fixture.py",
        'data.endswith(b"\\n")',
    ),
    (
        "python-self-test",
        "Scripts/generate-m5-fixture.py",
        'parser.add_argument("--self-test", action="store_true")',
    ),
    (
        "swift-word-count",
        "PrivatePresenterAppTests/M5PerformanceTestSupport.swift",
        "static let wordCount = 50_000",
    ),
    (
        "swift-byte-count",
        "PrivatePresenterAppTests/M5PerformanceTestSupport.swift",
        "static let byteCount = 499_999",
    ),
    (
        "swift-newline-count",
        "PrivatePresenterAppTests/M5PerformanceTestSupport.swift",
        "static let newlineCount = 2_499",
    ),
    (
        "swift-line-width",
        "PrivatePresenterAppTests/M5PerformanceTestSupport.swift",
        "lineWidth == 20",
    ),
    (
        "swift-first-token",
        "PrivatePresenterAppTests/M5PerformanceTestSupport.swift",
        'Data("word00000".utf8)',
    ),
    (
        "swift-middle-token",
        "PrivatePresenterAppTests/M5PerformanceTestSupport.swift",
        'Data("word25000".utf8)',
    ),
    (
        "swift-last-token",
        "PrivatePresenterAppTests/M5PerformanceTestSupport.swift",
        'Data("word49999".utf8)',
    ),
    (
        "swift-digest",
        "PrivatePresenterAppTests/M5PerformanceTestSupport.swift",
        '"d2aff66f0796536318d97d3b1d8080247728798dfa110725994019d58e7b09f4"',
    ),
)

EXPECTED_PERFORMANCE_CONTRACT_MARKERS = (
    (
        "baseline-opt-in",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        'private static let baselineEnvironmentKey = "PRIVATE_PRESENTER_M5_BASELINE"',
    ),
    (
        "load-two-seconds",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "private static let maximumLoadDuration = 2.000",
    ),
    (
        "edit-p95-fifty-ms",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "private static let maximumP95EditDuration = 0.050",
    ),
    (
        "stall-one-hundred-ms",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "private static let maximumEditOrStallDuration = 0.100",
    ),
    (
        "action-cadence-one-hundred-ms",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "private static let actionCadence = 0.100",
    ),
    (
        "three-hundred-actions",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "XCTAssertEqual(actions.count, 300)",
    ),
    (
        "fifty-six-action-cycles",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "XCTAssertEqual(actions.count / 6, 50)",
    ),
    (
        "exact-edit-offsets",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "offset == 0 || offset == 250_000 || offset == 499_999",
    ),
    (
        "restore-after-every-pair",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        'XCTAssertEqual(candidate, fixture, "pair \\((index + 1) / 2)")',
    ),
    (
        "nearest-rank-p95",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "Int(ceil(0.95 * Double(sortedSamples.count)))",
    ),
    (
        "nearest-rank-sample-285",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "XCTAssertEqual(oneBasedRank, 285)",
    ),
    (
        "scroll-warmup",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "warmupDuration: 60",
    ),
    (
        "scroll-measured-duration",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "measuredDuration: 300",
    ),
    (
        "scroll-total-timeline",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "totalSampleTimes: [120, 180, 240, 300, 360]",
    ),
    (
        "scroll-measured-timeline",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "XCTAssertEqual(result.measuredSampleTimes, [60, 120, 180, 240, 300])",
    ),
    (
        "five-memory-samples",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "XCTAssertEqual(externalRecord.allocationsLiveBytes.count, 5)",
    ),
    (
        "mib-divisor",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "let liveMiB = externalRecord.allocationsLiveBytes.map { Double($0) / 1_048_576 }",
    ),
    (
        "five-point-ols-x",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "y: liveMiB",
    ),
    (
        "ols-slope-one-mib-per-minute",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "XCTAssertLessThanOrEqual(slope, 1.0)",
    ),
    (
        "memory-delta-five-mib",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "XCTAssertLessThanOrEqual(liveMiB[4] - liveMiB[0], 5.0)",
    ),
    (
        "filesystem-delay-two-hundred-ms",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        "func testDelayedFilesystemDoesNotBlockEditAndFinalRevisionFlushes() async throws {\n"
        "        let fixture = try swiftFixture()\n"
        "        let result = try await makeHarness(fixture: fixture).runDelayedFilesystemEdit(\n"
        "            delay: 0.200",
    ),
    (
        "load-endpoint-snapshot",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        ".snapshotLoadBegan,",
    ),
    (
        "load-endpoint-reader-layout",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        ".firstReaderLayoutCompleted,",
    ),
    (
        "load-endpoint-edit",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        ".syntheticEditReflectedInReader,",
    ),
    (
        "load-endpoint-main-actor-sentinel",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        ".mainActorSentinelCompleted,",
    ),
    (
        "load-endpoint-measurement-end",
        "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
        ".measurementEnded,",
    ),
)

EXPECTED_SIGNPOST_STATIC_MARKERS = (
    (
        "subsystem",
        "PrivatePresenterApp/Services/PerformanceSignposter.swift",
        'static let subsystem = "com.privatepresenter.teleprompter"',
    ),
    (
        "categories",
        "PrivatePresenterApp/Interfaces/PerformanceSignposting.swift",
        "case load\n    case layout\n    case edit\n    case scroll\n    case persistence",
    ),
    (
        "operations",
        "PrivatePresenterApp/Interfaces/PerformanceSignposting.swift",
        'case restoreToInteractive = "restore-to-interactive"\n'
        '    case readerLayout = "reader-layout"\n'
        '    case editToVisible = "edit-to-visible"\n'
        '    case scrollSession = "scroll-session"\n'
        '    case scrollTick = "scroll-tick"\n'
        '    case snapshotEncode = "snapshot-encode"\n'
        '    case snapshotWrite = "snapshot-write"\n'
        '    case snapshotFlush = "snapshot-flush"',
    ),
    (
        "outcomes",
        "PrivatePresenterApp/Interfaces/PerformanceSignposting.swift",
        "case success\n    case failure\n    case cancelled",
    ),
    (
        "reasons",
        "PrivatePresenterApp/Interfaces/PerformanceSignposting.swift",
        "case initial\n    case restore\n    case resync\n    case debounced\n    case flush",
    ),
)

EXPECTED_SIGNPOST_CATEGORIES = ("load", "layout", "edit", "scroll", "persistence")
EXPECTED_SIGNPOST_OPERATIONS = (
    "restore-to-interactive",
    "reader-layout",
    "edit-to-visible",
    "scroll-session",
    "scroll-tick",
    "snapshot-encode",
    "snapshot-write",
    "snapshot-flush",
)
EXPECTED_SIGNPOST_OUTCOMES = ("success", "failure", "cancelled")
EXPECTED_SIGNPOST_REASONS = ("initial", "restore", "resync", "debounced", "flush")

EXPECTED_ORDERED_CONTRACT_MARKERS = (
    (
        "disconnect-anchor-enqueue-before-order-out",
        "PrivatePresenterAppTests/ScrollSessionControllerTests.swift",
        (
            'Array(observation.events.prefix(3)), ["stop", "enqueue", "orderOut"]',
            'firstIndex(of: "enqueue")',
            'firstIndex(of: "orderOut")',
            "XCTAssertLessThan(enqueue, orderOut)",
            "XCTAssertTrue(observation.persistenceWriteIsStillPending)",
            "XCTAssertTrue(observation.didOrderOutWhilePersistenceWasPending)",
        ),
    ),
    (
        "runtime-generation-before-topology-begin",
        "PrivatePresenterApp/App/AppRuntime.swift",
        (
            "let generation = issueDisplayGeneration()",
            "topologyGeneration = generation",
            "model.beginTopologyTransaction(generation: generation)",
        ),
    ),
    (
        "stale-generation-rejected-before-model-command",
        "PrivatePresenterApp/App/AppModel.swift",
        (
            "func acceptDisplayInventory(\n        _ inventory: RuntimeDisplayInventory,",
            "guard generation == activeTopologyGeneration else { return }",
            "send(.displayInventoryLoaded(inventory))",
        ),
    ),
    (
        "crash-restore-fail-closed",
        "PrivatePresenterAppTests/AppModelTests.swift",
        (
            "model.send(.restore(snapshot))",
            "XCTAssertTrue(model.isPaused)",
            "XCTAssertEqual(model.overlaySession.visibility, .hidden)",
            "XCTAssertNil(model.overlaySession.currentSessionDisplayID)",
            "XCTAssertNil(model.selectedDisplayID)",
            "XCTAssertTrue(model.displays.isEmpty)",
        ),
    ),
    (
        "quit-flush-before-quiescence-and-teardown",
        "PrivatePresenterApp/App/AppLifecycleCoordinator.swift",
        (
            "record(.rejectMutations)",
            "record(.pauseAndCapture)",
            "record(.hideAndShield)",
            "record(.stagePausedSnapshot)",
            "record(.flushPausedSnapshot)",
            "guard await flushPausedSnapshot() else {",
            "model.send(.enterTerminationQuiescence)",
            "record(.enterQuiescence)",
            "record(.closeCarbonDispatch)",
            "await closeCarbonDispatch()",
            "record(.unregisterHotKeys)",
            "await unregisterHotKeys()",
            "record(.stopFocusPointerDisplay)",
            "record(.teardownScrollSession)",
            "record(.removeStatusItem)",
            "record(.closeController)",
            "record(.terminateReady)",
        ),
    ),
    (
        "quiescence-before-hostile-callbacks",
        "PrivatePresenterAppTests/AppLifecycleCoordinatorTests.swift",
        (
            "harness.model.send(.beginTerminationAttempt)",
            "harness.model.send(.prepareForTermination)",
            "harness.model.send(.enterTerminationQuiescence)",
            "harness.effects.removeAll()",
            "harness.deliverQuiescentCallbacks()",
            "XCTAssertTrue(harness.effects.isEmpty)",
        ),
    ),
    (
        "carbon-close-before-unregister-and-retry",
        "PrivatePresenterAppTests/AppLifecycleCoordinatorTests.swift",
        (
            "service.closeDispatch()",
            "let report = service.shutdown()",
            "await Task.yield()",
            "let registrationCount = registrar.registerCount",
            "let retry = service.retry()",
            "XCTAssertEqual(registrar.registerCount, registrationCount)",
        ),
    ),
)

EXPECTED_PENDING_TEMPLATE_MARKERS = (
    "Status: PENDING",
    "M5 WSL source candidate",
    "Source SHA: PENDING",
    "Executable SHA-256: PENDING",
    "M3 native evidence: PENDING",
    "M4 native evidence: PENDING",
    "Promotion gate: external exact source/app SHA only",
)

EXPECTED_REVIEW_PENDING_TEMPLATE_MARKERS = (
    "Native SystemDisplay callback lifetime stress: PENDING",
)

EXPECTED_LEDGER_TITLES = (
    "Keep M5 claims inside the WSL and native evidence boundary",
    "Make every presenter control operable without sight or pointer",
    "Keep recovery fail-closed through display, crash, and quit races",
    "Measure hot paths without recording lecture identity",
    "Hold 50,000-word lectures to recorded responsiveness limits",
    "Keep M5 evidence reproducible without rewriting prior proof",
    "Prevent replay evidence from outrunning the measured product path",
)

EXPECTED_PRIOR_RED_GREEN_COMMITS = (
    ("f472cc2dfec0f44b10b2a21808b0ec7c89a292f5", "c680831d1592856733c6317351ff3bbd5cc35752"),
    ("a227aa08102be5d104762c690fd367e3aa25ca2c", "6cba1fb91eef94b3e60538750b3227d981536b58"),
    ("38b65fb977ddb6927ebe189233b78dc093946fd1", "96f7df80e701d03209e663e50d5722578c2ddff2"),
    ("56ecee16845415536a53391b99665213aead8289", "b696205d38c0a6d5d2f44bccebcf8daca02a8313"),
    ("7288a5c04b31fff902b83ebfbd7b636baff88369", "a56d9f2e963f92c60520e4b6efc19096c8a0ca7c"),
)

EXPECTED_REPLAY_MARKERS = (
    "Status: PENDING controlled-Mac replay and physical proof",
    "M3 native evidence: PENDING",
    "M4 native evidence: PENDING",
    "VoiceOver: PENDING",
    "AppKit/XCTest: PENDING",
    "Keynote/display/crash/quit: PENDING",
    "Release/Instruments/50,000-word performance: PENDING",
    "Replay every RED SHA before its immediate GREEN child",
    "A configuration or toolchain failure is not a valid RED",
    "Do not create a passed validation result",
    "Stop before M6",
)

EXPECTED_PRIVATE_SURFACE_MARKERS = (
    "SENTINEL_PRIVATE_",
    "document.text",
    "document.title",
    "displayID",
    "revision=",
    "path=",
    "url=",
    "userID",
    "String(describing:",
)


class Milestone5ValidatorContractTests(unittest.TestCase):
    @staticmethod
    def repo_path(path: Path) -> str | None:
        try:
            return path.resolve().relative_to(ROOT.resolve()).as_posix()
        except ValueError:
            return None

    def violations_with(
        self,
        replacements: dict[str, str],
        *,
        missing_paths: tuple[str, ...] = (),
        history: str | None = None,
    ) -> list[str]:
        original_read = VALIDATOR.read
        original_is_file = Path.is_file
        original_exists = Path.exists
        original_git = VALIDATOR.git

        def replaced_read(path: str) -> str:
            return replacements[path] if path in replacements else original_read(path)

        def replaced_is_file(path: Path) -> bool:
            relative = self.repo_path(path)
            if relative in missing_paths:
                return False
            if relative in replacements:
                return True
            return original_is_file(path)

        def replaced_exists(path: Path) -> bool:
            relative = self.repo_path(path)
            if relative in missing_paths:
                return False
            if relative in replacements:
                return True
            return original_exists(path)

        def replaced_git(*args: str) -> subprocess.CompletedProcess[str]:
            if history is not None and "log" in args:
                return subprocess.CompletedProcess(
                    ["git", *args], returncode=0, stdout=history, stderr=""
                )
            return original_git(*args)

        with (
            patch.object(VALIDATOR, "read", side_effect=replaced_read),
            patch.object(Path, "is_file", new=replaced_is_file),
            patch.object(Path, "exists", new=replaced_exists),
            patch.object(VALIDATOR, "git", side_effect=replaced_git),
        ):
            return VALIDATOR.validate_m5_source()

    def path_containing(self, marker: str, candidates: tuple[str, ...]) -> str:
        matches = [path for path in candidates if marker in VALIDATOR.read(path)]
        self.assertEqual(len(matches), 1, marker)
        return matches[0]

    def assert_violation_prefix(self, violations: list[str], prefix: str) -> None:
        self.assertTrue(
            any(item.startswith(prefix) for item in violations),
            f"expected {prefix!r} in {violations!r}",
        )

    def test_m5_plan_baseline_is_exact(self) -> None:
        self.assertEqual(VALIDATOR.M5_BASELINE, EXPECTED_BASELINE)

    def test_m5_full_planned_path_inventory_is_exact_without_phase_zero_placeholders(self) -> None:
        self.assertEqual(
            tuple(VALIDATOR.M5_PLANNED_REQUIRED_PATHS), EXPECTED_PLANNED_PATHS
        )

    def test_m5_full_required_and_mac_continuation_path_inventories_are_exact(self) -> None:
        self.assertEqual(
            tuple(VALIDATOR.M5_FULL_REQUIRED_PATHS), EXPECTED_FULL_REQUIRED_PATHS
        )
        self.assertEqual(
            tuple(VALIDATOR.M5_CONTINUATION_REQUIRED_PATHS),
            EXPECTED_CONTINUATION_PATHS,
        )

    def test_m5_accessibility_test_inventory_is_exact(self) -> None:
        self.assertEqual(
            tuple(VALIDATOR.M5_ACCESSIBILITY_NAMED_TESTS),
            EXPECTED_ACCESSIBILITY_TESTS,
        )

    def test_m5_lifecycle_test_inventory_is_exact(self) -> None:
        self.assertEqual(
            tuple(VALIDATOR.M5_LIFECYCLE_NAMED_TESTS), EXPECTED_LIFECYCLE_TESTS
        )

    def test_m5_signpost_and_performance_test_inventories_are_exact(self) -> None:
        self.assertEqual(
            tuple(VALIDATOR.M5_SIGNPOST_NAMED_TESTS), EXPECTED_SIGNPOST_TESTS
        )
        self.assertEqual(
            tuple(VALIDATOR.M5_PERFORMANCE_NAMED_TESTS), EXPECTED_PERFORMANCE_TESTS
        )

    def test_m5_independent_review_test_inventory_is_exact(self) -> None:
        self.assertEqual(
            tuple(VALIDATOR.M5_INDEPENDENT_REVIEW_NAMED_TESTS),
            EXPECTED_INDEPENDENT_REVIEW_NAMED_TESTS,
        )

    def test_m5_protected_and_pending_evidence_inventories_are_exact(self) -> None:
        self.assertEqual(tuple(VALIDATOR.M5_PROTECTED_PATHS), EXPECTED_PROTECTED_PATHS)
        self.assertEqual(
            tuple(VALIDATOR.M5_PENDING_EVIDENCE_PATHS), EXPECTED_PENDING_EVIDENCE
        )

    def test_m5_prohibited_permission_logging_network_and_m6_surfaces_are_exact(self) -> None:
        self.assertEqual(
            tuple(VALIDATOR.M5_PROHIBITED_PATTERNS), EXPECTED_PROHIBITED_PATTERNS
        )

    def test_m5_fixture_performance_signpost_and_order_contracts_are_exact(self) -> None:
        self.assertEqual(
            tuple(VALIDATOR.M5_FIXTURE_CONTRACT_MARKERS),
            EXPECTED_FIXTURE_CONTRACT_MARKERS,
        )
        self.assertEqual(
            tuple(VALIDATOR.M5_PERFORMANCE_CONTRACT_MARKERS),
            EXPECTED_PERFORMANCE_CONTRACT_MARKERS,
        )
        self.assertEqual(
            tuple(VALIDATOR.M5_SIGNPOST_STATIC_MARKERS),
            EXPECTED_SIGNPOST_STATIC_MARKERS,
        )
        self.assertEqual(
            tuple(VALIDATOR.M5_ORDERED_CONTRACT_MARKERS),
            EXPECTED_ORDERED_CONTRACT_MARKERS,
        )

    def test_m5_closed_signpost_metadata_inventories_are_exact(self) -> None:
        self.assertEqual(
            tuple(VALIDATOR.M5_SIGNPOST_CATEGORIES), EXPECTED_SIGNPOST_CATEGORIES
        )
        self.assertEqual(
            tuple(VALIDATOR.M5_SIGNPOST_OPERATIONS), EXPECTED_SIGNPOST_OPERATIONS
        )
        self.assertEqual(
            tuple(VALIDATOR.M5_SIGNPOST_OUTCOMES), EXPECTED_SIGNPOST_OUTCOMES
        )
        self.assertEqual(tuple(VALIDATOR.M5_SIGNPOST_REASONS), EXPECTED_SIGNPOST_REASONS)
        self.assertEqual(
            tuple(VALIDATOR.M5_PRIVATE_SURFACE_MARKERS),
            EXPECTED_PRIVATE_SURFACE_MARKERS,
        )

    def test_m5_pending_ledger_and_replay_contracts_are_exact(self) -> None:
        self.assertEqual(
            tuple(VALIDATOR.M5_PENDING_TEMPLATE_MARKERS),
            EXPECTED_PENDING_TEMPLATE_MARKERS,
        )
        self.assertEqual(tuple(VALIDATOR.M5_LEDGER_TITLES), EXPECTED_LEDGER_TITLES)
        self.assertEqual(
            tuple(VALIDATOR.M5_PRIOR_RED_GREEN_COMMITS),
            EXPECTED_PRIOR_RED_GREEN_COMMITS,
        )
        self.assertEqual(tuple(VALIDATOR.M5_REPLAY_MARKERS), EXPECTED_REPLAY_MARKERS)

    def test_m5_native_callback_stress_field_stays_explicitly_pending(self) -> None:
        self.assertEqual(
            tuple(VALIDATOR.M5_REVIEW_PENDING_TEMPLATE_MARKERS),
            EXPECTED_REVIEW_PENDING_TEMPLATE_MARKERS,
        )

    def test_each_full_required_path_is_enforced(self) -> None:
        for path in EXPECTED_FULL_REQUIRED_PATHS:
            with self.subTest(path=path):
                violations = self.violations_with({}, missing_paths=(path,))
                self.assertIn(f"missing-path:{path}", violations)

    def test_each_exact_named_test_is_enforced(self) -> None:
        accessibility_candidates = (
            "PrivatePresenterAppTests/PresenterAccessibilityTests.swift",
            "PrivatePresenterUITests/ControllerAccessibilityUITests.swift",
            "PrivatePresenterUITests/M5UITestSupport.swift",
        )
        lifecycle_candidates = (
            "PrivatePresenterAppTests/AppLifecycleCoordinatorTests.swift",
            "PrivatePresenterAppTests/AppModelTests.swift",
            "PrivatePresenterAppTests/SystemDisplayServiceTests.swift",
            "PrivatePresenterAppTests/ScrollSessionControllerTests.swift",
            "PrivatePresenterAppTests/SnapshotStoreTests.swift",
        )
        groups = (
            ("accessibility", EXPECTED_ACCESSIBILITY_TESTS, accessibility_candidates),
            ("lifecycle", EXPECTED_LIFECYCLE_TESTS, lifecycle_candidates),
            (
                "signpost",
                EXPECTED_SIGNPOST_TESTS,
                ("PrivatePresenterAppTests/PerformanceSignposterTests.swift",),
            ),
            (
                "performance",
                EXPECTED_PERFORMANCE_TESTS,
                ("PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",),
            ),
        )
        for group, names, candidates in groups:
            for name in names:
                with self.subTest(group=group, name=name):
                    path = self.path_containing(name, candidates)
                    source = VALIDATOR.read(path)
                    self.assertEqual(source.count(name), 1, f"{path}:{name}")
                    violations = self.violations_with(
                        {path: source.replace(name, f"removed_{name}", 1)}
                    )
                    self.assertIn(f"missing-test:{name}", violations)

    def test_each_independent_review_named_test_is_enforced(self) -> None:
        candidates = (
            "PrivatePresenterAppTests/FiftyThousandWordPerformanceTests.swift",
            "PrivatePresenterAppTests/PerformanceSignposterTests.swift",
            "PrivatePresenterAppTests/AppModelTests.swift",
            "PrivatePresenterAppTests/PresenterAccessibilityTests.swift",
        )
        for name in EXPECTED_INDEPENDENT_REVIEW_NAMED_TESTS:
            with self.subTest(name=name):
                path = self.path_containing(name, candidates)
                source = VALIDATOR.read(path)
                self.assertEqual(source.count(name), 1, f"{path}:{name}")
                violations = self.violations_with(
                    {path: source.replace(name, f"removed_{name}", 1)}
                )
                self.assertIn(f"missing-test:{name}", violations)

    def test_accessibility_help_bridge_and_actual_target_frames_are_enforced(self) -> None:
        accessibility_path = (
            "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift"
        )
        accessibility_source = VALIDATOR.read(accessibility_path)
        help_bridge = ".accessibilityHint(Text(entry.help))"
        self.assertEqual(accessibility_source.count(help_bridge), 1)
        with self.subTest(contract="help-bridge"):
            violations = self.violations_with(
                {
                    accessibility_path: accessibility_source.replace(
                        help_bridge, "removed-accessibility-help-bridge", 1
                    )
                }
            )
            self.assertIn("accessibility:missing-help-bridge", violations)

        overlay_path = "PrivatePresenterApp/Overlay/OverlayChromeView.swift"
        overlay_source = VALIDATOR.read(overlay_path)
        target_frame = ".frame(minWidth: 44, minHeight: 44)"
        self.assertEqual(overlay_source.count(target_frame), 3)
        with self.subTest(contract="actual-44-point-frame"):
            violations = self.violations_with(
                {
                    overlay_path: overlay_source.replace(
                        target_frame, "removed-accessibility-target-frame", 1
                    )
                }
            )
            self.assertIn("accessibility:missing-44-point-frame", violations)

    def test_each_fixture_threshold_cadence_offset_p95_ols_and_timeline_marker_is_enforced(
        self,
    ) -> None:
        marker_groups = (
            ("fixture", EXPECTED_FIXTURE_CONTRACT_MARKERS),
            ("performance", EXPECTED_PERFORMANCE_CONTRACT_MARKERS),
            ("signpost", EXPECTED_SIGNPOST_STATIC_MARKERS),
        )
        for violation_class, markers in marker_groups:
            for label, path, marker in markers:
                with self.subTest(contract=violation_class, marker=label):
                    source = VALIDATOR.read(path)
                    self.assertIn(marker, source, f"contract fixture drift: {path}:{label}")
                    violations = self.violations_with(
                        {path: source.replace(marker, f"removed-{label}", 1)}
                    )
                    self.assertIn(f"{violation_class}:missing-marker:{label}", violations)

    def test_each_disconnect_generation_stale_crash_quiescence_quit_and_carbon_order_is_enforced(
        self,
    ) -> None:
        for label, path, markers in EXPECTED_ORDERED_CONTRACT_MARKERS:
            source = VALIDATOR.read(path)
            cursor = -1
            marker_positions: list[tuple[str, int]] = []
            for marker in markers:
                next_cursor = source.find(marker, cursor + 1)
                self.assertGreater(next_cursor, cursor, f"order fixture drift: {label}:{marker}")
                marker_positions.append((marker, next_cursor))
                cursor = next_cursor
            for marker, position in marker_positions:
                with self.subTest(order=label, marker=marker):
                    mutation = (
                        source[:position]
                        + "removed-order-marker"
                        + source[position + len(marker) :]
                    )
                    violations = self.violations_with(
                        {path: mutation}
                    )
                    self.assertIn(f"order:{label}", violations)

    def test_each_prohibition_is_enforced_and_m6_result_is_rejected(self) -> None:
        path = "PrivatePresenterApp/App/AppModel.swift"
        source = VALIDATOR.read(path)
        for pattern in EXPECTED_PROHIBITED_PATTERNS:
            with self.subTest(pattern=pattern):
                violations = self.violations_with(
                    {path: source + f"\n// injected mutation: {pattern}\n"}
                )
                self.assert_violation_prefix(violations, f"prohibited:{pattern}:")

        violations = self.violations_with(
            {"docs/validation/visual-result.md": "Status: PENDING\n"}
        )
        self.assertIn("scope:m6-visual-polish", violations)

    def test_signposting_has_one_os_boundary_closed_metadata_and_no_cross_boundary_tokens(
        self,
    ) -> None:
        for path in (
            "PrivatePresenterApp/App/AppEffect.swift",
            "PrivatePresenterApp/Services/SnapshotStore.swift",
            "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift",
            "Packages/TeleprompterCore/Sources/PromptingCore/Models/ScriptDocument.swift",
        ):
            source = VALIDATOR.read(path)
            with self.subTest(kind="os-boundary", path=path):
                violations = self.violations_with({path: source + "\nimport OS\n"})
                self.assert_violation_prefix(violations, "signpost:OS-boundary:")
            with self.subTest(kind="token-boundary", path=path):
                violations = self.violations_with(
                    {path: source + "\nlet leaked = PerformanceSignpostToken(rawValue: 1)\n"}
                )
                self.assert_violation_prefix(
                    violations, "signpost:token-crosses-boundary:"
                )

        interface_path = "PrivatePresenterApp/Interfaces/PerformanceSignposting.swift"
        interface = VALIDATOR.read(interface_path)
        violations = self.violations_with(
            {
                interface_path: interface.replace(
                    "reason: PerformanceSignpostReason?",
                    "reason: PerformanceSignpostReason?, metadata: String?",
                    1,
                )
            }
        )
        self.assert_violation_prefix(violations, "signpost:arbitrary-metadata:")

        for enum_marker in (
            "enum PerformanceSignpostCategory",
            "enum PerformanceSignpostOperation",
            "enum PerformanceSignpostOutcome",
            "enum PerformanceSignpostReason",
        ):
            with self.subTest(closed_enum=enum_marker):
                mutated = interface.replace(enum_marker + ":", enum_marker + ":")
                insertion = mutated.index("\n}", mutated.index(enum_marker))
                mutated = mutated[:insertion] + "\n    case arbitrary" + mutated[insertion:]
                violations = self.violations_with({interface_path: mutated})
                self.assert_violation_prefix(violations, "signpost:closed-metadata:")

    def test_private_sentinels_are_rejected_from_app_effect_core_snapshot_and_public_surfaces(
        self,
    ) -> None:
        for path in (
            "PrivatePresenterApp/App/AppEffect.swift",
            "Packages/TeleprompterCore/Sources/PromptingCore/Models/ScriptDocument.swift",
            "PrivatePresenterApp/Services/SnapshotStore.swift",
            "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift",
        ):
            source = VALIDATOR.read(path)
            for marker in EXPECTED_PRIVATE_SURFACE_MARKERS:
                with self.subTest(path=path, marker=marker):
                    violations = self.violations_with(
                        {path: source + f"\n// private mutation: {marker}\n"}
                    )
                    self.assert_violation_prefix(violations, "privacy:private-surface:")

    def test_each_pending_template_stays_literal_pending_and_requires_external_exact_sha_gate(
        self,
    ) -> None:
        canonical = "\n".join(EXPECTED_PENDING_TEMPLATE_MARKERS) + "\n"
        for path in EXPECTED_PENDING_EVIDENCE:
            source = VALIDATOR.read(path) if (ROOT / path).is_file() else canonical
            for marker in EXPECTED_PENDING_TEMPLATE_MARKERS:
                with self.subTest(path=path, marker=marker):
                    violations = self.violations_with(
                        {path: source.replace(marker, f"removed-{marker}", 1)}
                    )
                    self.assertIn(f"evidence:missing-marker:{path}:{marker}", violations)

            promoted = source.replace("Status: PENDING", "Status: PASS", 1)
            violations = self.violations_with({path: promoted})
            self.assertIn(f"evidence:status-not-pending:{path}", violations)

    def test_native_system_display_callback_lifetime_stress_cannot_disappear(self) -> None:
        path = "docs/validation/m5-display-crash-quit-result.md"
        marker = EXPECTED_REVIEW_PENDING_TEMPLATE_MARKERS[0]
        source = VALIDATOR.read(path)
        canonical = source if marker in source.splitlines() else source + f"\n{marker}\n"
        violations = self.violations_with(
            {path: canonical.replace(marker, "removed-native-callback-stress", 1)}
        )
        self.assertIn(f"evidence:missing-marker:{path}:{marker}", violations)

    def test_each_protected_prior_artifact_remains_byte_exact(self) -> None:
        for path in EXPECTED_PROTECTED_PATHS:
            with self.subTest(path=path):
                if Path(path).suffix == ".png":
                    continue
                violations = self.violations_with(
                    {path: VALIDATOR.read(path) + "\nprotected mutation\n"}
                )
                self.assertIn(f"protected-byte:{path}", violations)

    def test_dependency_schema_permission_and_entitlement_boundaries_remain_enforced(self) -> None:
        snapshot = (
            "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/"
            "PersistedSnapshot.swift"
        )
        document = (
            "Packages/TeleprompterCore/Sources/PromptingCore/Models/"
            "ScriptDocument.swift"
        )
        cases = (
            (
                "project.yml",
                VALIDATOR.read("project.yml").replace("- sdk: Carbon.framework", "- sdk: Network.framework"),
                "dependency:project-yml-changed",
            ),
            (
                "Packages/TeleprompterCore/Package.swift",
                VALIDATOR.read("Packages/TeleprompterCore/Package.swift").replace('dependencies: ["PromptingCore"]', 'dependencies: ["NetworkClient"]'),
                "dependency:package-swift-changed",
            ),
            (
                snapshot,
                VALIDATOR.read(snapshot).replace(
                    "currentSchemaVersion = 1", "currentSchemaVersion = 2"
                ),
                "schema:persisted-snapshot-version",
            ),
            (
                document,
                VALIDATOR.read(document).replace(
                    "currentSchemaVersion = 1", "currentSchemaVersion = 2"
                ),
                "schema:script-document-version",
            ),
            (
                "PrivatePresenterApp/Info.plist",
                VALIDATOR.read("PrivatePresenterApp/Info.plist") + "\npermission mutation\n",
                "permission:info-plist-changed",
            ),
            (
                "PrivatePresenterApp/Resources/PrivatePresenter.entitlements",
                VALIDATOR.read(
                    "PrivatePresenterApp/Resources/PrivatePresenter.entitlements"
                )
                + "\ncom.apple.security.network.client\n",
                "entitlement:changed",
            ),
        )
        for path, mutation, label in cases:
            with self.subTest(path=path, label=label):
                violations = self.violations_with({path: mutation})
                self.assertIn(label, violations)

    def test_ancestry_complete_red_green_ledger_and_replay_markers_are_enforced(self) -> None:
        original_git = VALIDATOR.git

        def no_ancestry(*args: str) -> subprocess.CompletedProcess[str]:
            if args[:3] == ("merge-base", "--is-ancestor", EXPECTED_BASELINE):
                return subprocess.CompletedProcess(
                    ["git", *args], returncode=1, stdout="", stderr=""
                )
            return original_git(*args)

        with patch.object(VALIDATOR, "git", side_effect=no_ancestry):
            self.assertIn(
                "ancestry:m5-plan-baseline-not-ancestor",
                VALIDATOR.validate_m5_source(),
            )

        violations = self.violations_with({}, history="")
        for title in EXPECTED_LEDGER_TITLES:
            self.assertIn(f"ledger:red-green-pair:{title}", violations)

        continuation_path = EXPECTED_CONTINUATION_PATHS[0]
        canonical = "\n".join(EXPECTED_REPLAY_MARKERS) + "\n"
        for marker in EXPECTED_REPLAY_MARKERS:
            with self.subTest(replay_marker=marker):
                violations = self.violations_with(
                    {
                        continuation_path: canonical.replace(
                            marker, f"removed-{marker}", 1
                        )
                    }
                )
                self.assertIn(f"continuation:missing-replay-marker:{marker}", violations)

    def test_continuation_source_identity_and_checksum_manifests_are_enforced(self) -> None:
        continuation_path = EXPECTED_CONTINUATION_PATHS[0]
        head = VALIDATOR.git("rev-parse", "HEAD").stdout.strip()
        source = (
            VALIDATOR.read(continuation_path)
            if (ROOT / continuation_path).is_file()
            else "\n".join(EXPECTED_REPLAY_MARKERS)
            + f"\nExact WSL source SHA: `{head}`\n"
        )
        violations = self.violations_with(
            {
                continuation_path: source.replace(
                    f"Exact WSL source SHA: `{head}`",
                    "Exact WSL source SHA: `0000000000000000000000000000000000000000`",
                    1,
                )
            }
        )
        self.assertIn("continuation:source-sha", violations)

        for path in EXPECTED_CONTINUATION_PATHS[1:3]:
            manifest = (
                VALIDATOR.read(path)
                if (ROOT / path).is_file()
                else "0" * 64 + "  missing-artifact\n"
            )
            mutated = "z" + manifest[1:]
            with self.subTest(checksum=path):
                violations = self.violations_with({path: mutated})
                self.assertIn(f"continuation:checksum:{path}", violations)

    def test_source_manifest_is_the_exact_unique_baseline_to_head_path_set(self) -> None:
        manifest_path = EXPECTED_CONTINUATION_PATHS[2]
        manifest = VALIDATOR.read(manifest_path)
        lines = manifest.splitlines()
        self.assertTrue(lines)

        paths = [line.split("  ", 1)[1] for line in lines]
        expected_paths = tuple(
            sorted(
                filter(
                    None,
                    VALIDATOR.git(
                        "diff",
                        "--name-only",
                        "--diff-filter=ACMR",
                        f"{EXPECTED_BASELINE}..HEAD",
                    ).stdout.splitlines(),
                )
            )
        )
        self.assertEqual(tuple(paths), expected_paths)
        self.assertEqual(len(paths), len(set(paths)))

        with self.subTest(mutation="missing-path"):
            missing = "\n".join(lines[1:]) + "\n"
            violations = self.violations_with({manifest_path: missing})
            self.assertIn("continuation:source-manifest-path-set", violations)

        with self.subTest(mutation="duplicate-path"):
            duplicate = manifest + lines[0] + "\n"
            violations = self.violations_with({manifest_path: duplicate})
            self.assertIn("continuation:source-manifest-duplicate", violations)

    def test_aggregate_m2_through_m5_current_source_compatibility_stays_green(self) -> None:
        for milestone in (2, 3, 4, 5):
            with self.subTest(milestone=milestone):
                validator = getattr(VALIDATOR, f"validate_m{milestone}_source")
                self.assertEqual(
                    validator(),
                    [],
                    "later-milestone source must satisfy the historical contract without "
                    "removing its epoch-specific mutation checks",
                )

    def test_phase_zero_validator_rejects_scope_privacy_and_metadata_mutations(self) -> None:
        path = "PrivatePresenterApp/App/AppModel.swift"
        mutation = VALIDATOR.read(path) + """
// LinearGradient( #34466F #202B4B #F7F8FC
// Logger( os_log( URLSession AXIsProcessTrusted CGEventTap
// OSSignposter is restricted to the sole performance signposter boundary.
// performanceSignposter.begin(.readerLayout, metadata: \"SENTINEL_PRIVATE_SCRIPT\")
"""
        violations = self.violations_with({path: mutation})
        for label in (
            "scope:m6-visual-polish",
            "prohibited:Logger(",
            "prohibited:os_log(",
            "prohibited:URLSession",
            "prohibited:AXIsProcessTrusted",
            "prohibited:CGEventTap",
            "signpost:OS-boundary",
            "signpost:arbitrary-metadata",
            "signpost:private-sentinel",
        ):
            self.assertTrue(any(item.startswith(label) for item in violations), label)

    def test_phase_zero_validator_rejects_protected_dependency_schema_and_entitlement_mutations(
        self,
    ) -> None:
        snapshot = (
            "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/"
            "PersistedSnapshot.swift"
        )
        replacements = {
            "HANDOFF.md": VALIDATOR.read("HANDOFF.md") + "\nmutation\n",
            "project.yml": VALIDATOR.read("project.yml").replace("- sdk: Carbon.framework", "- sdk: Network.framework"),
            snapshot: VALIDATOR.read(snapshot).replace(
                "currentSchemaVersion = 1", "currentSchemaVersion = 2"
            ),
            "PrivatePresenterApp/Resources/PrivatePresenter.entitlements": (
                VALIDATOR.read(
                    "PrivatePresenterApp/Resources/PrivatePresenter.entitlements"
                )
                + "\ncom.apple.security.network.client\n"
            ),
        }
        violations = self.violations_with(replacements)
        for expected in (
            "protected-byte:HANDOFF.md",
            "dependency:project-yml-changed",
            "schema:persisted-snapshot-version",
            "entitlement:changed",
            "entitlement:non-sandbox-surface",
        ):
            self.assertIn(expected, violations)

    def test_phase_zero_current_source_is_green_and_main_invokes_m5_validator(self) -> None:
        self.assertEqual(VALIDATOR.validate_m5_source(), [])
        self.assertIn("validate_m5_source()", inspect.getsource(VALIDATOR.main))
        self.assertNotIn("phase-zero", (VALIDATOR.validate_m5_source.__doc__ or "").lower())
        self.assertNotIn("phase-zero", inspect.getsource(VALIDATOR.main).lower())


if __name__ == "__main__":
    unittest.main()
