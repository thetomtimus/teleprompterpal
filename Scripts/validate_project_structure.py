#!/usr/bin/env python3
"""Validate the committed Milestone 0 stabilization source without third-party modules."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import plistlib
import platform
import re
import subprocess
import sys
import tarfile
from functools import lru_cache
from iphone_structure import PORTABLE_MOVES, mac_project_compatible, core_package_compatible, validate_phone_boundary


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_PATHS = (
    ".xcodegen-version",
    "project.yml",
    "Config/Shared.xcconfig",
    "Config/Debug.xcconfig",
    "Config/Release.xcconfig",
    "Scripts/bootstrap-macos.sh",
    "Scripts/verify-wsl.sh",
    "Scripts/verify-macos.sh",
    "Scripts/verify-no-network.sh",
    "Scripts/verify-m0-proof-provenance.sh",
    "Scripts/test-verify-m0-proof-provenance.sh",
    "Scripts/run-m0-phase-a-diagnosis.sh",
    "Packages/TeleprompterCore/Package.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ScriptDocument.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ReadingAnchor.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/TeleprompterPreferences.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/OverlaySession.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/KeyboardShortcut.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/PersistedSnapshot.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/SnapshotMigrator.swift",
    "Packages/TeleprompterCore/Tests/TeleprompterCoreTests/CoreStateModelTests.swift",
    "Packages/TeleprompterCore/Tests/TeleprompterCoreTests/SnapshotMigratorTests.swift",
    "PrivatePresenterApp/Info.plist",
    "PrivatePresenterApp/App/AppCommand.swift",
    "PrivatePresenterApp/App/AppEffect.swift",
    "PrivatePresenterApp/App/AppModel.swift",
    "PrivatePresenterApp/App/DependencyContainer.swift",
    "PrivatePresenterApp/Interfaces/SnapshotFileSystem.swift",
    "PrivatePresenterApp/Interfaces/SnapshotScheduling.swift",
    "PrivatePresenterApp/Services/SnapshotStore.swift",
    "PrivatePresenterApp/Resources/PrivatePresenter.entitlements",
    "PrivatePresenterApp/Services/DiagnosticHotKeyService.swift",
    "PrivatePresenterApp/Services/DiagnosticEvidenceRecorder.swift",
    "PrivatePresenterApp/Services/DiagnosticObserverSet.swift",
    "PrivatePresenterApp/Services/SystemDisplayService.swift",
    "PrivatePresenterAppTests/OverlayPanelConfigurationTests.swift",
    "PrivatePresenterAppTests/OverlayPanelControllerTests.swift",
    "PrivatePresenterAppTests/AppModelTests.swift",
    "PrivatePresenterAppTests/SnapshotStoreTests.swift",
    "PrivatePresenterAppTests/DiagnosticEvidenceRecorderTests.swift",
    "PrivatePresenterAppTests/DiagnosticHotKeyServiceTests.swift",
    "PrivatePresenterAppTests/DiagnosticObserverLifecycleTests.swift",
    "PrivatePresenterAppTests/SystemDisplayServiceTests.swift",
    "PrivatePresenterUITests/PrivatePresenterUITestShell.swift",
    "docs/validation/source-artifact-checksums.sha256",
    "docs/validation/overlay-proof-template.md",
    "docs/validation/m0-phase-b-physical-selection-2026-07-14.md",
)

PROJECT_MARKERS = (
    "minimumXcodeGenVersion: 2.45.4",
    'macOS: "14.0"',
    'SWIFT_VERSION: "6.0"',
    "PrivatePresenter:",
    "PrivatePresenterAppTests:",
    "PrivatePresenterUITests:",
    "com.privatepresenter.teleprompter",
    "PRODUCT_MODULE_NAME: PrivatePresenter",
    "Carbon.framework",
    "Packages/TeleprompterCore",
    "TeleprompterCore:",
    "shared: true",
)

APP_SOURCE_MARKERS = (
    "PRIVATE_PRESENTER_PROOF_LEVEL",
    "PRIVATE_PRESENTER_STALE_CONTROLLER_FRAME",
    "DisplayTopologyEvaluator()",
    "refreshDisplayInventory",
    "RegisterEventHotKey",
    "Control-Option-H",
    "Control-Option-L",
    "CGGetOnlineDisplayList",
    "isDrawableDestination",
    "constrainFrameRect",
    "case top, bottom, left, right",
    "case topLeft, topRight, bottomLeft, bottomRight",
    "WorkspaceFocusProbe.capture",
    "PRIVATE_PRESENTER_ORDERING",
    "PRIVATE_PRESENTER_CONTROLLER_COHORT",
    "PRIVATE_PRESENTER_REPETITION",
    "PRIVATE_PRESENTER_EVIDENCE_EXECUTABLE_SHA256",
    "PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG_SHA256",
    "PRIVATE_PRESENTER_EVIDENCE_BUILD_MANIFEST",
    "configurationBound",
    "sessionCompletion",
    "EVIDENCE_QUEUE_OVERFLOW",
    "HOT_KEY_REGISTRATION_FAILED",
    "applyContainedFrame",
    "selectedFullFrame",
    "selectedVisibleFrame",
    "containmentFrame",
    "appliedFrame",
    "OverlayPanelOrderingMode",
    "NSApplication.willBecomeActiveNotification",
    "NSWorkspace.didActivateApplicationNotification",
)

PHASE_A_NAMED_TESTS = (
    "testStabilizationRetainsV1CanonicalSnapshotAfterDiagnosticLockChange",
    "testStabilizationRestoreRemainsHiddenPausedUntilPrivacyConfirmation",
    "testStabilizationStartupRestoresBeforeTopologyAndRegistersControlsLast",
    "testStabilizationRuntimeStillConstructsExactlyOneAppModel",
    "testStabilizationServicesShareTheRuntimeModelIdentity",
    "testDiagnosticStateNeverEntersPersistedSnapshot",
    "testEvidenceEnvelopeCarriesSessionCorrelationSourceTimeSequenceAndFixedKind",
    "testCarbonReceiptIsStampedBeforeMainDispatchForSameCorrelation",
    "testCorrelatedEventsRetainStrictRecorderOrderAcrossDelayedSamples",
    "testEvidenceUsesLocalApplicationSupportValidationDirectory",
    "testEvidenceAppendDoesNotEraseEarlierEvents",
    "testEvidenceWriterNeverPerformsFileIOOnHotKeyOrMainCriticalPath",
    "testEvidenceAndFixedErrorsNeverContainScriptTitleContextOrRawEnvironment",
    "testRecorderFailureDoesNotBlockPrivacyOrHotKeyDispatch",
    "testRecorderFailurePermanentlyInvalidatesCellWhileActionsContinue",
    "testSessionCompletionRequiresResolvedPathExistingFileAndSuccessfulFlush",
    "testEvidenceHeaderBindsFullCommitLevelAndOrdering",
    "testQueueSaturationAtomicallyInvalidatesCellWithoutDelayingHotKeyOrPrivacy",
    "testQueueOverflowEmitsFixedFaultWhenCapacityReturns",
    "testQueueOverflowCannotBecomeValidAfterSuccessfulFlush",
    "testBoundedIngressRejectsNewestEnvelopeAtCapacityWithoutWaiting",
    "testQueueOverflowInvalidationDoesNotRequireFaultEnvelopeCapacity",
    "testOverflowFaultIsEmittedOnceAfterWriterCapacityReturns",
    "testHotKeyDispatchContinuesWhileEvidenceQueueIsSaturated",
    "testPrivacyDirectivesContinueInOrderWhileEvidenceQueueIsSaturated",
    "testOverflowAndLaterSinkFailurePreserveFirstPermanentInvalidation",
    "testConfigurationBoundIncludesControllerCohortAndRepetition",
    "testOnlyRepetitionsOneThroughThreeAreAccepted",
    "testInvalidRepetitionUsesFixedCodeWithoutEchoingInput",
    "testConfigurationBoundIncludesExecutableSHA256AndBuildLogPathAndHash",
    "testExecutableHashRequiresSixtyFourLowercaseHexCharacters",
    "testInvalidExecutableHashUsesFixedCodeWithoutEchoingInput",
    "testInvalidBuildLogHashUsesFixedCodeWithoutEchoingInput",
    "testEvidenceWritesOnlyToSiblingPendingPathBeforeCompletion",
    "testSessionCompletionIsLastSerializedEventBeforeSynchronization",
    "testSynchronizationAndClosePrecedeAtomicFinalRename",
    "testFinalPathAppearsOnlyAfterAtomicRename",
    "testSynchronizationFailureNeverPublishesFinalEvidenceFile",
    "testCloseFailureNeverPublishesFinalEvidenceFile",
    "testAtomicRenameFailureNeverPublishesAcceptedFinalFile",
    "testPendingFileIsNeverAcceptedAsProof",
    "testFinalizationFailurePermanentlyInvalidatesCell",
    "testControlOptionHRetainsVisibilityAction",
    "testObserversInstallBeforeVisibilityHotKeyAndTearDownAfterUnregistration",
    "testNoEventsAreAcceptedAfterObserverTeardown",
    "testApplicationObserversCaptureWillAndDidBecomeActive",
    "testApplicationObserversCaptureWillAndDidResignActive",
    "testWorkspaceObserverCapturesDidActivateApplication",
    "testWindowObserversRetainTransientKeyMainOrderAndOcclusionNotifications",
    "testFocusSnapshotsUseImmediateNextRunLoop100msAnd500msSchedule",
    "testDelayedSamplesAreCancelledAfterSessionTeardown",
    "testControllerPlacementRecordsEntryAndExitWithoutPresentation",
    "testStartupPresentationRecordsFrameShowWindowAndPresentationCount",
    "testPhaseAControllerObserverRecordsVisibilityOrderKeyMainAndOcclusion",
    "testPhaseAInstrumentationDoesNotChangeControllerFrameVisibilityOrShowCount",
    "testColdShowTraceSupportsControllerVisibleAndOrderedOutStates",
    "testEvidenceDistinguishesVisibleDesktopSpaceAndOrderedOutCohorts",
    "testObservedVisibleControllerMatchesVisibleDesktopSpaceCohort",
    "testObservedOrderedOutControllerMatchesOrderedOutCohort",
    "testMissingControllerWindowCausesCohortMismatch",
    "testControllerCohortMismatchPermanentlyInvalidatesCellBeforeFirstHotKey",
    "testObservedCohortValidationNeverPresentsOrOrdersController",
    "testConfigurationBoundPrecedesCorrelatedCarbonReceipt",
    "testNormalQuitWaitsForAllCorrelatedSamplesBeforeCompletion",
    "testPostCorrelationQuitActivationIsTaggedAndExcludedFromFocusVerdict",
    "testUncorrelatedActivationWithoutTerminationStillFailsFocusVerdict",
    "testOrderedOutCohortQuitDoesNotPresentOrOrderController",
    "testOrderingModesAreExactlyFrontAndFrontRegardless",
    "testBothOrderingModesAvoidKeyMainAndExplicitActivation",
    "testDefaultProofLevelUsesLowestPhysicallyPassingStatusBarEvidence",
    "testDefaultOrderingRetainsFrontRegardlessAfterPhysicalEvidence",
    "testOrderingSelectionChoosesOnlyPassingMode",
    "testOrderingSelectionRetainsCurrentSourceDefaultWhenBothModesAreEquivalent",
    "testOrderingSelectionUsesSafetyVectorBeforeDefaultTieBreak",
    "testOrderingSelectionRejectsLevelWhenNeitherModePasses",
    "testLevelSelectionPrefersFloatingOnlyAfterCompletePassingOrdering",
    "testConfigurationSnapshotExportsCommitOrderingAndLevel",
    "testActivationPolicyIsSetOnlyAtBootstrap",
    "testForbiddenWindowLevelsAndFocusWorkaroundsAreAbsent",
)

PHASE_B_NAMED_TESTS = (
    "testControlOptionLDispatchesDistinctLockAction",
    "testCarbonIdentifiersDecodeToDistinctActions",
    "testRegistrationFailureCleansUpBothHotKeys",
    "testSuccessfulTerminationUnregistersBothDiagnosticChords",
    "testBothRegistrationFailuresInvalidatePhysicalPrecondition",
    "testBothHotKeyActionsPropagateCorrelationID",
    "testEvidenceExportsSelectedAndAppliedFramesSeparately",
    "testPrivacyDirectiveEffectAndApplicationOrderShareCorrelation",
    "testRuntimeInventoryRequiresDrawableDestinationsAndTopology",
    "testCGOnlyTopologyMemberHasNoVisibleFrameScaleOrDestinationEligibility",
    "testOnlineMirroredSinkMissingFromDrawableScreensStillBlocks",
    "testOnlineDisplayQueryFailureFailsClosed",
    "testOnlineDisplayCountRaceFailsClosed",
    "testVerifiedMirroringRequiresHardwareMirrorFacts",
    "testCGOnlyDisplayCannotBecomeSelectedDestination",
    "testPanelConstrainFrameIsASecondContainmentDefense",
    "testWiredDragAndResizeUpdatesRemainContained",
    "testEveryAppliedFrameIsRecordedExactlyOnce",
    "testRecordedFrameIncludesSeparateSelectedFullVisibleAndContainmentFrames",
    "testLockRestoresClickThroughWithoutChangingFrame",
    "testSecondContainmentDefenseRejectsCrossDisplayFrame",
    "testDragAndResizeNeverPresentNormalController",
    "testPlacementPreservesVisibleControllerState",
    "testPlacementPreservesOrderedOutControllerState",
    "testMirroringWhileVisibleHidesAndShieldsBeforeRecovery",
    "testSelectedPrivateDisplayDisconnectHidesBeforeRecovery",
    "testControllerRemainsShieldedAfterReconnectUntilConfirmation",
    "testPendingShowCannotSurviveTopologyChange",
    "testNonDrawableOnlineMirrorStillUsesExactWarningAndCannotBeBypassed",
    "testTopologyPlacementNeverPresentsNormalController",
    "testHLockTopologyDragAndResizeNeverOrderControllerOnScreen",
    "testDefaultProofLevelUsesLowestPhysicallyPassingStatusBarEvidence",
    "testLevelSelectionRetainsFloatingBeforeComparingStatusBarSafety",
)

PROVENANCE_FIXTURE_TESTS = (
    "testProvenanceVerifierAcceptsMatchingCleanManifest",
    "testProvenanceVerifierRejectsExecutableHashMismatch",
    "testProvenanceVerifierRejectsBuildLogHashMismatch",
    "testProvenanceVerifierRejectsCommitMismatch",
    "testProvenanceVerifierRejectsMissingBuildLog",
    "testProvenanceVerifierRejectsDirtyTree",
    "testProvenanceVerifierRejectsDebugDylibIndirection",
    "testSameExecutableHashIsRequiredAcrossSmokeAndPhysicalEvidence",
    "testProvenanceVerifierRejectsWrongBuildLogCommit",
    "testProvenanceVerifierRejectsMissingOrDuplicateBuildLogCleanStatus",
    "testProvenanceVerifierRejectsIncompleteCorrelation",
    "testProvenanceVerifierRejectsDuplicateCorrelationEvent",
)

NAMED_TESTS = (
    "testMirroredSelectionBlocksOpening",
    "testMirrorSourceStillBlocksOpening",
    "testNoBuiltInRequiresSelection",
    "testAmbiguousFingerprintRequiresConfirmation",
    "testRemovedSelectionReturnsHiddenPausedRecovery",
    "testEvaluatorNeverAutoSelectsExternalDisplay",
    "testDefaultFrameIsTopCenteredSeventyByThirtyFivePercent",
    "testNormalizedFrameRestoresOnSameFingerprint",
    "testEveryIntermediateDragFrameStaysContained",
    "testResizeCannotCrossAdjacentScreen",
    "testNegativeAndVerticalLayoutsStayContained",
    "testResolutionChangeReclamps",
    "testPanelIsBorderlessNonactivatingAndNotNativelyResizable",
    "testCustomResizeHandlesApplyOnlyContainedFrames",
    "testPanelJoinsAllSpacesAsFullScreenAuxiliary",
    "testPanelUsesBoundedLevel",
    "testLockedPanelIgnoresMouseAndCannotBecomeKeyOrMain",
    "testUnlockedPanelRestoresInteractionWithoutAcceptingKey",
    "testShowDoesNotActivateApplication",
    "testReadingSurfaceInteriorIsOpaque",
    "testControllerCreatesExactlyOnePanel",
    "testNoIntermediateSetFrameIsUnsafe",
    "testTopologyEffectsPauseHideShieldBeforeQuery",
    "testControllerStartsShielded",
    "testControllerNeverReopensUnredactedOnExternalScreen",
    "testMissingDisplayStagesBuiltInHidden",
    "testRecoveryRequiresConfirmationAndNeverAutoResumes",
    "testDefaultTitleAndPreferencesMatchPRD",
    "testFontRangeClampsTo24Through96",
    "testSpeedRangeClampsTo10Through240",
    "testDefaultShortcutMapMatchesPRD",
    "testReadingAnchorClampsWithoutSplittingUnicode",
    "testCodableRoundTripPreservesUnicodeScript",
    "testPersistedSnapshotExcludesPlayingState",
    "testPersistedSnapshotExcludesRuntimeDisplayID",
    "testCanonicalEncodingIsByteEqualForPermutedInput",
    "testDuplicateFrameAndShortcutEntriesAreRejected",
    "testUnknownShortcutModifierIsMalformed",
    "testSnapshotAndDocumentSchemaMustAgree",
    "testCoreProductionSourcesImportFoundationOnly",
    "testV1MigratesIdempotently",
    "testV1MigrationPreservesUnicodeAndRevision",
    "testUnknownFutureSchemaFailsWithoutDataLoss",
    "testUnsupportedLegacySchemaDoesNotGuess",
    "testRestoreAlwaysReturnsPaused",
    "testRestoreRequiresFreshPrivacyAssessmentBeforeShow",
    "testMalformedSnapshotIsReported",
    "testMigrationErrorsNeverContainScriptContent",
    "testProductionURLUsesSandboxApplicationSupportSubdirectory",
    "testSaveAtomicallyReplacesSnapshot",
    "testFailedReplacePreservesLastKnownGoodSnapshot",
    "testDebounceCoalescesRapidEdits",
    "testStaleRevisionCannotOverwriteNewerPendingSnapshot",
    "testEqualRevisionWithDifferentPayloadIsConflict",
    "testFlushPersistsLatestRevision",
    "testFlushCancelsPendingDebounceWithoutDuplicateWrite",
    "testSaveArrivingAroundFlushCannotLetStaleWriteWin",
    "testMalformedFileIsQuarantined",
    "testQuarantineFailurePreservesSourceAndBlocksWrites",
    "testFutureSchemaIsPreservedInPlace",
    "testFutureSchemaBlocksSubsequentSaveAndFlushWithoutChangingBytes",
    "testQuarantineCollisionDoesNotDeleteEvidence",
    "testFailedWriteRetainsPendingSnapshotAndPersistedRevision",
    "testScriptIsNeverWrittenToUserDefaults",
    "testDiagnosticsAndErrorsDoNotContainScriptContent",
    "testCommandsChangeStateBeforeEffects",
    "testEmptyScriptCannotStart",
    "testWhitespaceOnlyScriptCannotStart",
    "testRestartPausesAtBeginning",
    "testRelaunchReassessesPrivacyBeforeShow",
    "testAppRuntimeRestoreAndPrivacyOrderingBlocksEarlyShow",
    "testRestoreClearsCurrentSessionDisplayIdentity",
    "testClearRequiresConfirmedCommand",
    "testClearWaitsForSuccessfulPreClearFlush",
    "testFailedPreClearFlushPreservesScript",
    "testInterveningEditInvalidatesPendingClear",
    "testStaleClearCompletionCannotEraseScript",
    "testPostClearSnapshotPersistsImmediatelyWithoutDebounce",
    "testConfirmedClearIncrementsRevisionsAndPersistsEmptySnapshot",
    "testRuntimeAndControllerShareOneAuthoritativeModel",
    "testAppRuntimeConstructsExactlyOneAppModel",
)

DATA_SAFETY_PATTERNS = (
    r"\bUserDefaults\b",
    r"\bprint\s*\(",
    r"\bLogger\s*\(",
    r"\bos_log\s*\(",
    r"\bUNUserNotificationCenter\b",
    r"\bNSUserNotification\b",
)

M2_REQUIRED_PATHS = (
    "PrivatePresenterApp/Text/ScriptTextEdit.swift",
    "PrivatePresenterApp/Controller/EditorTextSystem.swift",
    "PrivatePresenterApp/Controller/ScriptEditorTextView.swift",
    "PrivatePresenterApp/Controller/ControllerPresentation.swift",
    "PrivatePresenterApp/Controller/DebugDiagnosticsView.swift",
    "PrivatePresenterApp/Overlay/ReaderTextSystem.swift",
    "PrivatePresenterApp/Overlay/ReaderTextView.swift",
    "PrivatePresenterAppTests/EditorTextSystemTests.swift",
    "PrivatePresenterAppTests/ReaderTextSystemTests.swift",
    "PrivatePresenterAppTests/ControllerPresentationTests.swift",
)

M2_NAMED_TESTS = (
    "testEditorReportsEditedRangeAndDelta",
    "testScriptTextEditValidatesBaseAndResultRevision",
    "testScriptTextEditIsSendableAcrossActorBoundary",
    "testUTF16EmojiEditBoundaries",
    "testCombiningCharacterEditUsesUTF16DeltaWithoutCorruption",
    "testProgrammaticEditorSyncDoesNotEmitUserEdit",
    "testEditorCallbackIsMainActorIsolated",
    "testEditorUsesTextKit2WithoutLegacyLayoutManager",
    "testStaleOrOutOfOrderEditCannotOverwriteAuthority",
    "testAcceptedEditMutatesStateBeforeReaderAndSnapshotEffects",
    "testIncrementalEditDoesNotReplaceReaderStorage",
    "testRevisionGapPerformsOneResync",
    "testMultipleUpdatesDuringGapRequestOnlyOneResync",
    "testDuplicateAndStaleReaderUpdatesAreIgnored",
    "testContiguousInvalidRangePerformsOneAuthoritativeResync",
    "testStorageLengthDivergencePerformsOneAuthoritativeResync",
    "testResyncToLatestRevisionRestoresIncrementalDelivery",
    "testInitialRestoreClearAndLatchedGapOrApplicationFailureAreOnlyFullReplacementReasons",
    "testReaderResyncCallbackIsMainActorIsolated",
    "testReaderUsesTextKit2WithoutLegacyLayoutManager",
    "testFontAndAlignmentUpdatesDoNotMutateReaderText",
    "testActiveBandToggleDoesNotMutateReaderText",
    "testEmptyInstructionAndDisabledStart",
    "testClearPresentsConfirmation",
    "testWhitespaceOnlyScriptUsesEmptyInstruction",
    "testNonemptyM2ScriptStillExplainsScrollingIsM3",
    "testM2StartPauseRestartDoNotDispatchPlaybackCommands",
    "testM2FocusModeExplainsM4AndDoesNotChangeChrome",
    "testProductControllerExposesOpenCloseAndHideShowThroughOnePanelState",
    "testTitleTrimsDefaultsAndCapsWithoutSplittingCharacter",
    "testFontSizeAlignmentAndActiveBandPersistThroughV1Snapshot",
    "testAcceptedEditSchedulesAutosaveAfterAuthoritativeMutation",
    "testRapidEditsDebounceToLatestSnapshot",
    "testAutosaveDoesNotBlockMainActorEffectDispatch",
    "testAutosaveDiagnosticsExcludeScriptTitleAndReplacementText",
    "testMapsNSScreenNumberToSessionID",
    "testBuildsFingerprintFromUUIDAndHardware",
    "testDuplicateZeroSerialDisplaysAreAmbiguous",
    "testRawDisplayIDIsNotEncoded",
    "testQueryFailureIsUnsafe",
    "testMissingOrWrongTypedNSScreenNumberFailsClosed",
    "testDuplicateDrawableSessionIDsFailClosed",
    "testDuplicateOnlineSessionIDsFailClosed",
    "testZeroSessionIDFailsClosed",
    "testZeroVendorModelAndSerialAreNotStrongIdentity",
    "testLocalizedNameDoesNotOverrideHardwareConflict",
    "testAmbiguousFingerprintCannotRestoreAcrossSessionWithoutConfirmation",
    "testExplicitCurrentSessionChoiceDoesNotEnterEncodedSnapshot",
    "testMirroringWarningUsesRequiredText",
    "testShieldPrecedesWarningAndReposition",
    "testSelectedDisplayNameIsVisible",
    "testAmbiguityRequiresExplicitConfirmation",
    "testMenuNeverContainsPrivateTitle",
    "testRecoveryNeverResumesAutomatically",
    "testPerDisplayFramesRemainSeparate",
    "testExactMirroringWarningIsSeparateFromRecoveryGuidance",
    "testSelectedNameIsHiddenUntilCurrentSessionConfirmation",
    "testTopologyStatusDistinguishesExtendedMirroredSingleMissingAmbiguousAndQueryFailure",
    "testAmbiguousWeakDisplayFrameIsNotAutoRestoredOrPersisted",
    "testRestoredNormalizedFrameReclampsToCurrentContainment",
    "testFrameCallbackPersistsOnlyCurrentConfirmedDisplayFingerprint",
    "testDisplayLossPausesHidesShieldsBeforeFallbackPlacement",
    "testReconnectRemainsHiddenPausedUntilExplicitConfirmation",
    "testPendingShowCannotSurviveTopologyChange",
    "testWindowMenuDiagnosticAndAccessibilityLabelsExcludeSentinelPrivateContent",
    "testM2PreservesOnePanelAndOneAppModel",
    "testM2PreservesStatusBarFrontRegardlessAndPermanentNonKeyNonMain",
    "testM2PreservesDiagnosticHAndLDirectDispatchWithoutControllerRaise",
    "testM2PreservesEveryDragAndResizeFrameWithinSelectedDisplay",
    "testM2PreservesOpaqueRoundedReaderSurface",
)

M2_PROHIBITED_PATTERNS = (
    "NSStatusItem",
    "MenuBarExtra",
    "addGlobalMonitorForEvents",
    "CGEventTap",
    "AXIsProcessTrusted",
    "WKWebView",
    "URLSession",
    ".screenSaver",
    ".layoutManager",
)


M3_REQUIRED_PATHS = (
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

M3_CANONICAL_NAMED_TESTS = (
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

M3_ADDED_NAMED_TESTS = (
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

M3_PROHIBITED_PATTERNS = (
    "NSStatusItem",
    "MenuBarExtra",
    "addGlobalMonitorForEvents",
    "addLocalMonitorForEvents",
    "CGEventTap",
    "CGEvent.tapCreate",
    "AXIsProcessTrusted",
    "AXUIElement",
    "AXObserver",
    "WKWebView",
    "URLSession",
    "URLRequest",
    "NSURLConnection",
    "NWConnection",
    "import Network",
    "import ApplicationServices",
    ".layoutManager",
    "NSLayoutManager",
    "NSClassFromString",
    "dlsym(",
)

M3_ALLOWED_PACKAGE_DEPENDENCIES = ("TeleprompterCore", "Carbon.framework")
M3_BASELINE = "802953089e88369e2a8e9fb744f4e32b30d9727d"

M4_REQUIRED_PATHS = (
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Shortcuts/ShortcutValidator.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Focus/FocusChromeStateMachine.swift",
    "Packages/TeleprompterCore/Tests/TeleprompterCoreTests/ShortcutValidatorTests.swift",
    "Packages/TeleprompterCore/Tests/TeleprompterCoreTests/FocusChromeStateMachineTests.swift",
    "PrivatePresenterApp/Interfaces/HotKeyRegistering.swift",
    "PrivatePresenterApp/Services/CarbonHotKeyService.swift",
    "PrivatePresenterApp/Overlay/FocusModeController.swift",
    "PrivatePresenterApp/Overlay/PointerPresenceMonitor.swift",
    "PrivatePresenterApp/Overlay/OverlayChromeView.swift",
    "PrivatePresenterApp/Menu/StatusItemController.swift",
    "PrivatePresenterApp/App/AppLifecycleCoordinator.swift",
    "PrivatePresenterAppTests/CarbonHotKeyServiceTests.swift",
    "PrivatePresenterAppTests/FocusModeControllerTests.swift",
    "PrivatePresenterUITests/MenuLifecycleUITests.swift",
    "Scripts/test_validate_project_structure_m4.py",
    "Scripts/run-m4-hotkey-collision-holder.swift",
)

M4_CANONICAL_NAMED_TESTS = (
    "testDefaultsMatchPRD",
    "testBareSpaceAndArrowsAreRejected",
    "testDuplicateChordIsRejected",
    "testCustomChordRoundTrips",
    "testRegistersEveryActionOnce",
    "testReconfigurationUnregistersOldChordTransactionally",
    "testPartialRegistrationRollsBack",
    "testCollisionSurfacesWithoutFallback",
    "testShutdownUnregistersAll",
    "testHandlerDispatchesExpectedCommand",
    "testEveryFocusTransition",
    "testLockedFocusHidesAfterTwoSeconds",
    "testPointerPresenceRevealsWithoutDisablingClickThrough",
    "testDynamicCanBecomeKeyRequiresUnlockedAndActive",
    "testUnlockNeverActivates",
    "testReduceMotionRemovesDecorativeFade",
    "testSingleModelIsSharedByBothWindowsAndStatusItem",
    "testMenuContainsFiveRequiredActions",
    "testClosingControllerDoesNotQuit",
    "testShowControllerReusesInstance",
    "testQuitFlushesPausedStateBeforeUnregisterAndTerminate",
)

M4_ADDED_NAMED_TESTS = (
    "testEveryProductShortcutRequiresModifier",
    "testMissingAndDuplicateActionsAreRejected",
    "testCanonicalBindingsUseStableActionOrder",
    "testInvalidRestoredBindingsUseDefaultsWithoutDiscardingDocument",
    "testShortcutRoundTripKeepsPersistedSnapshotSchemaOne",
    "testCustomizationIsDisabledByDefaultUntilPhysicalProof",
    "testInitialFailureLeavesNoActiveHotKeysOrHandler",
    "testStableCarbonIDsMapAllSevenActionsExactlyOnce",
    "testUnknownSignatureOrIdentifierIsNotHandled",
    "testReconfigurationKeepsUnchangedReferencesRegistered",
    "testChangedOldReferencesUnregisterBeforeProposedRegistration",
    "testOldUnregistrationFailureDoesNotStageProposalAndReportsUnknownState",
    "testStagedCallbacksDoNotDispatchBeforeCommit",
    "testFailedProposalRestoresCompleteOldMap",
    "testRollbackFailureTearsDownAllRegistrationsAndReportsNoActiveHotKeys",
    "testCleanupFailureNeverClaimsZeroActiveRegistrations",
    "testUnknownCleanupDisablesRetryUntilRelaunch",
    "testCleanupUnknownMessageIsFixedAndContentNeutral",
    "testProposedBindingsPersistOnlyAfterRegistrationCommit",
    "testFailedProposalKeepsPersistedOldBindings",
    "testRetryFromDegradedStateRegistersCleanSevenActionSet",
    "testDispatchRunsOnMainActorWithoutActivatingApplication",
    "testHotKeyCommandsCannotBypassEmptyScriptOrPrivacyGuards",
    "testProductAndDiagnosticRegistrarsNeverRunTogether",
    "testShutdownRemovesHandlerAfterReferencesAndIsIdempotent",
    "testShutdownReportsUnregistrationAndHandlerRemovalFailures",
    "testUnlockedAndFocusOffStatesNeverArmHideDeadline",
    "testLockedFocusArmsExactlyTwoSecondDeadline",
    "testStaleHideDeadlineIsIgnored",
    "testPointerExitRearmsFullDeadline",
    "testHideAndTeardownCancelDeadlineAndSampling",
    "testPointerSamplerRunsOnlyWhileVisibleLockedAndFocused",
    "testPointerSamplerUsesLocationOnlyAtOneHundredMillisecondInterval",
    "testLockedPointerRevealKeepsIgnoresMouseEventsTrue",
    "testInactiveApplicationCannotYieldKeyPanelEvenWhenUnlocked",
    "testShowHideLockFocusAndPointerPathsNeverActivateOrMakeKey",
    "testCanBecomeMainRemainsFalseInEveryState",
    "testFocusChromeUsesSameAppModelIdentityAsReaderWindow",
    "testOverlayHostingControllerIsCreatedOnceOnConnect",
    "testConnectModelIsIdempotentAndRejectsDifferentModel",
    "testFocusChromeDoesNotMutateTextOrChangeReaderInset",
    "testFocusPreferenceRoundTripsSchemaOne",
    "testStatusItemOwnsExactlyFiveActionItems",
    "testMenuAndStatusTitlesNeverContainScriptTitle",
    "testEveryMenuActionDispatchesTypedAppCommand",
    "testQuitRequestReachesLifecycleAsTypedAppCommand",
    "testClosingControllerLeavesOverlayStatusAndHotKeysAlive",
    "testShowControllerWhileUnsafeRemainsShielded",
    "testStartupRegistersProductHotKeysAfterRestoreAndPrivacyAssessment",
    "testStartupCollisionLeavesMenuAndControllerRecoveryAvailable",
    "testQuitStopsAndCapturesBeforePausedSnapshotFlush",
    "testFlushFailureKeepsRecoveryServicesAndCancelsTermination",
    "testSuccessfulQuitStopsCallbacksBeforeStatusItemRemovalAndTerminateReply",
    "testRepeatedQuitAndShutdownAreIdempotent",
    "testRuntimeConstructsNoSecondModelPanelControllerStatusItemOrScrollOwner",
)

M4_PROHIBITED_PATTERNS = (
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
    "VoiceOver",
    "50_000",
)

M4_BASELINE = "6aba2060c4308ea90d8973b2f606e5646e85d596"

M5_BASELINE = "d7e79ba1623d76a5df07d2b482bae9ea795ea3cb"

M5_PLANNED_REQUIRED_PATHS = (
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

M5_ACCESSIBILITY_NAMED_TESTS = (
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

M5_LIFECYCLE_NAMED_TESTS = (
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

M5_SIGNPOST_NAMED_TESTS = (
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

M5_PERFORMANCE_NAMED_TESTS = (
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

M5_INDEPENDENT_REVIEW_NAMED_TESTS = (
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

M5_PROTECTED_PATHS = (
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

M5_PENDING_EVIDENCE_PATHS = (
    "docs/validation/m5-accessibility-result.md",
    "docs/validation/m5-display-crash-quit-result.md",
    "docs/validation/performance-result.md",
)

M5_PROHIBITED_PATTERNS = (
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

M5_PHASE_ZERO_REQUIRED_PATHS = (
    "Scripts/test_validate_project_structure_m5.py",
    "Scripts/validate_project_structure.py",
    "docs/plans/2026-07-15-milestone-5-accessibility-performance-hardening.md",
)

M5_PHASE_ZERO_NAMED_TESTS = (
    "test_m5_plan_baseline_is_exact",
    "test_m5_full_planned_path_inventory_is_exact_without_phase_zero_placeholders",
    "test_m5_accessibility_test_inventory_is_exact",
    "test_m5_lifecycle_test_inventory_is_exact",
    "test_m5_signpost_and_performance_test_inventories_are_exact",
    "test_m5_protected_and_pending_evidence_inventories_are_exact",
    "test_m5_prohibited_permission_logging_network_and_m6_surfaces_are_exact",
    "test_phase_zero_validator_rejects_scope_privacy_and_metadata_mutations",
    "test_phase_zero_validator_rejects_protected_dependency_schema_and_entitlement_mutations",
    "test_phase_zero_current_source_is_green_and_main_invokes_m5_validator",
)

M5_CONTINUATION_REQUIRED_PATHS = (
    ".omx/handoff/private-presenter-m5/MAC-CONTINUATION.md",
    ".omx/handoff/private-presenter-m5/m5-artifacts.sha256",
    ".omx/handoff/private-presenter-m5/m5-source-files.sha256",
    ".omx/handoff/private-presenter-m5/private-presenter-m5-source.tar",
    ".omx/handoff/private-presenter-m5/private-presenter-m5-wsl.bundle",
)

M5_FIXTURE_CONTRACT_MARKERS = (
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

M5_PERFORMANCE_CONTRACT_MARKERS = (
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

M5_SIGNPOST_STATIC_MARKERS = (
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

M5_SIGNPOST_CATEGORIES = ("load", "layout", "edit", "scroll", "persistence")

M5_SIGNPOST_OPERATIONS = (
    "restore-to-interactive",
    "reader-layout",
    "edit-to-visible",
    "scroll-session",
    "scroll-tick",
    "snapshot-encode",
    "snapshot-write",
    "snapshot-flush",
)

M5_SIGNPOST_OUTCOMES = ("success", "failure", "cancelled")

M5_SIGNPOST_REASONS = ("initial", "restore", "resync", "debounced", "flush")

M5_ORDERED_CONTRACT_MARKERS = (
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

M5_PENDING_TEMPLATE_MARKERS = (
    "Status: PENDING",
    "M5 WSL source candidate",
    "Source SHA: PENDING",
    "Executable SHA-256: PENDING",
    "M3 native evidence: PENDING",
    "M4 native evidence: PENDING",
    "Promotion gate: external exact source/app SHA only",
)

M5_REVIEW_PENDING_TEMPLATE_MARKERS = (
    "Native SystemDisplay callback lifetime stress: PENDING",
)

M5_LEDGER_TITLES = (
    "Keep M5 claims inside the WSL and native evidence boundary",
    "Make every presenter control operable without sight or pointer",
    "Keep recovery fail-closed through display, crash, and quit races",
    "Measure hot paths without recording lecture identity",
    "Hold 50,000-word lectures to recorded responsiveness limits",
    "Keep M5 evidence reproducible without rewriting prior proof",
    "Prevent replay evidence from outrunning the measured product path",
)

M5_PRIOR_RED_GREEN_COMMITS = (
    ("f472cc2dfec0f44b10b2a21808b0ec7c89a292f5", "c680831d1592856733c6317351ff3bbd5cc35752"),
    ("a227aa08102be5d104762c690fd367e3aa25ca2c", "6cba1fb91eef94b3e60538750b3227d981536b58"),
    ("38b65fb977ddb6927ebe189233b78dc093946fd1", "96f7df80e701d03209e663e50d5722578c2ddff2"),
    ("56ecee16845415536a53391b99665213aead8289", "b696205d38c0a6d5d2f44bccebcf8daca02a8313"),
    ("7288a5c04b31fff902b83ebfbd7b636baff88369", "a56d9f2e963f92c60520e4b6efc19096c8a0ca7c"),
)

M5_REPLAY_MARKERS = (
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

M5_PRIVATE_SURFACE_MARKERS = (
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

M5_FULL_REQUIRED_PATHS = (
    M5_PLANNED_REQUIRED_PATHS
    + ("PrivatePresenterAppTests/M5PerformanceTestSupport.swift",)
    + M5_CONTINUATION_REQUIRED_PATHS
)

M5_CONTRACT_MARKER_COUNTS = {
    ('fixture', 'python-word-count'): 1,
    ('fixture', 'python-line-width'): 1,
    ('fixture', 'python-utf8-count'): 1,
    ('fixture', 'python-utf16-count'): 1,
    ('fixture', 'python-newline-count'): 1,
    ('fixture', 'python-digest'): 1,
    ('fixture', 'python-token-format'): 1,
    ('fixture', 'python-first-token'): 1,
    ('fixture', 'python-middle-token'): 1,
    ('fixture', 'python-last-token'): 1,
    ('fixture', 'python-no-final-newline'): 1,
    ('fixture', 'python-self-test'): 1,
    ('fixture', 'swift-word-count'): 1,
    ('fixture', 'swift-byte-count'): 1,
    ('fixture', 'swift-newline-count'): 1,
    ('fixture', 'swift-line-width'): 1,
    ('fixture', 'swift-first-token'): 1,
    ('fixture', 'swift-middle-token'): 1,
    ('fixture', 'swift-last-token'): 1,
    ('fixture', 'swift-digest'): 1,
    ('performance', 'baseline-opt-in'): 1,
    ('performance', 'load-two-seconds'): 1,
    ('performance', 'edit-p95-fifty-ms'): 1,
    ('performance', 'stall-one-hundred-ms'): 1,
    ('performance', 'action-cadence-one-hundred-ms'): 1,
    ('performance', 'three-hundred-actions'): 1,
    ('performance', 'fifty-six-action-cycles'): 1,
    ('performance', 'exact-edit-offsets'): 1,
    ('performance', 'restore-after-every-pair'): 1,
    ('performance', 'nearest-rank-p95'): 2,
    ('performance', 'nearest-rank-sample-285'): 1,
    ('performance', 'scroll-warmup'): 1,
    ('performance', 'scroll-measured-duration'): 1,
    ('performance', 'scroll-total-timeline'): 1,
    ('performance', 'scroll-measured-timeline'): 1,
    ('performance', 'five-memory-samples'): 1,
    ('performance', 'mib-divisor'): 1,
    ('performance', 'five-point-ols-x'): 1,
    ('performance', 'ols-slope-one-mib-per-minute'): 1,
    ('performance', 'memory-delta-five-mib'): 1,
    ('performance', 'filesystem-delay-two-hundred-ms'): 1,
    ('performance', 'load-endpoint-snapshot'): 1,
    ('performance', 'load-endpoint-reader-layout'): 2,
    ('performance', 'load-endpoint-edit'): 2,
    ('performance', 'load-endpoint-main-actor-sentinel'): 2,
    ('performance', 'load-endpoint-measurement-end'): 1,
    ('signpost', 'subsystem'): 1,
    ('signpost', 'categories'): 1,
    ('signpost', 'operations'): 1,
    ('signpost', 'outcomes'): 1,
    ('signpost', 'reasons'): 1,
}

M5_ORDER_MARKER_COUNTS = {
    ('disconnect-anchor-enqueue-before-order-out', 'Array(observation.events.prefix(3)), ["stop", "enqueue", "orderOut"]'): 1,
    ('disconnect-anchor-enqueue-before-order-out', 'firstIndex(of: "enqueue")'): 1,
    ('disconnect-anchor-enqueue-before-order-out', 'firstIndex(of: "orderOut")'): 1,
    ('disconnect-anchor-enqueue-before-order-out', 'XCTAssertLessThan(enqueue, orderOut)'): 1,
    ('disconnect-anchor-enqueue-before-order-out', 'XCTAssertTrue(observation.persistenceWriteIsStillPending)'): 1,
    ('disconnect-anchor-enqueue-before-order-out', 'XCTAssertTrue(observation.didOrderOutWhilePersistenceWasPending)'): 1,
    ('runtime-generation-before-topology-begin', 'let generation = issueDisplayGeneration()'): 1,
    ('runtime-generation-before-topology-begin', 'topologyGeneration = generation'): 1,
    ('runtime-generation-before-topology-begin', 'model.beginTopologyTransaction(generation: generation)'): 1,
    ('stale-generation-rejected-before-model-command', 'func acceptDisplayInventory(\n        _ inventory: RuntimeDisplayInventory,'): 2,
    ('stale-generation-rejected-before-model-command', 'guard generation == activeTopologyGeneration else { return }'): 4,
    ('stale-generation-rejected-before-model-command', 'send(.displayInventoryLoaded(inventory))'): 2,
    ('crash-restore-fail-closed', 'model.send(.restore(snapshot))'): 1,
    ('crash-restore-fail-closed', 'XCTAssertTrue(model.isPaused)'): 9,
    ('crash-restore-fail-closed', 'XCTAssertEqual(model.overlaySession.visibility, .hidden)'): 9,
    ('crash-restore-fail-closed', 'XCTAssertNil(model.overlaySession.currentSessionDisplayID)'): 2,
    ('crash-restore-fail-closed', 'XCTAssertNil(model.selectedDisplayID)'): 4,
    ('crash-restore-fail-closed', 'XCTAssertTrue(model.displays.isEmpty)'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'record(.rejectMutations)'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'record(.pauseAndCapture)'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'record(.hideAndShield)'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'record(.stagePausedSnapshot)'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'record(.flushPausedSnapshot)'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'guard await flushPausedSnapshot() else {'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'model.send(.enterTerminationQuiescence)'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'record(.enterQuiescence)'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'record(.closeCarbonDispatch)'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'await closeCarbonDispatch()'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'record(.unregisterHotKeys)'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'await unregisterHotKeys()'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'record(.stopFocusPointerDisplay)'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'record(.teardownScrollSession)'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'record(.removeStatusItem)'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'record(.closeController)'): 1,
    ('quit-flush-before-quiescence-and-teardown', 'record(.terminateReady)'): 1,
    ('quiescence-before-hostile-callbacks', 'harness.model.send(.beginTerminationAttempt)'): 1,
    ('quiescence-before-hostile-callbacks', 'harness.model.send(.prepareForTermination)'): 1,
    ('quiescence-before-hostile-callbacks', 'harness.model.send(.enterTerminationQuiescence)'): 1,
    ('quiescence-before-hostile-callbacks', 'harness.effects.removeAll()'): 1,
    ('quiescence-before-hostile-callbacks', 'harness.deliverQuiescentCallbacks()'): 2,
    ('quiescence-before-hostile-callbacks', 'XCTAssertTrue(harness.effects.isEmpty)'): 1,
    ('carbon-close-before-unregister-and-retry', 'service.closeDispatch()'): 1,
    ('carbon-close-before-unregister-and-retry', 'let report = service.shutdown()'): 1,
    ('carbon-close-before-unregister-and-retry', 'await Task.yield()'): 3,
    ('carbon-close-before-unregister-and-retry', 'let registrationCount = registrar.registerCount'): 1,
    ('carbon-close-before-unregister-and-retry', 'let retry = service.retry()'): 1,
    ('carbon-close-before-unregister-and-retry', 'XCTAssertEqual(registrar.registerCount, registrationCount)'): 1,
}

M6_PLAN_COMMIT = "3c1aadd9fb50ab6f335580ebd72e6609f2cfa2f0"
M6_FINAL_SOURCE_COMMIT = "9fc74287456179b63928b53c81318644592e1fbf"
M6_PLAN_PARENT = "1ac13dbbdae1c53eea06033c353d22ab0919e8a5"
M6_PLAN_PATH = (
    "docs/plans/2026-07-16-milestone-6-reference-faithful-visual-polish.md"
)
M6_M5_SOURCE_TREE = "3d90bcd2c1851b36e0adc774c99a2416da7ba5b8"
M6_M5_HANDOFF_MANIFEST_SHA256 = (
    "29a38045cb4f01c29c5973baeb3ec57de0cda249d52e82e385481a2724f20eae"
)

M6_PROTECTED_PATHS = (
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
    M6_PLAN_PATH,
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

M6_FINAL_EVIDENCE_PATHS = (
    "docs/validation/visual-result.md",
    ".omx/handoff/private-presenter-m6/MAC-CONTINUATION.md",
    ".omx/handoff/private-presenter-m6/m6-artifacts.sha256",
    ".omx/handoff/private-presenter-m6/m6-source-files.sha256",
    ".omx/handoff/private-presenter-m6/private-presenter-m6-source.tar",
    ".omx/handoff/private-presenter-m6/private-presenter-m6-wsl.bundle",
)

M6_RESULT_PATH = "docs/validation/visual-result.md"
M6_CONTINUATION_DIR = ".omx/handoff/private-presenter-m6"
M6_CONTINUATION_FILES = (
    "MAC-CONTINUATION.md",
    "m6-artifacts.sha256",
    "m6-source-files.sha256",
    "private-presenter-m6-source.tar",
    "private-presenter-m6-wsl.bundle",
)
M6_ARTIFACT_MANIFEST_ENTRIES = (
    "MAC-CONTINUATION.md",
    "m6-source-files.sha256",
    "private-presenter-m6-source.tar",
    "private-presenter-m6-wsl.bundle",
)
M6_SCREENSHOT_STATES = (
    "unlocked",
    "locked",
    "focus-hidden",
    "bright-background",
    "active-band",
)
M6_REFERENCE_HASHES = (
    (
        "teleprompter-ui-reference",
        "352437f2fc06efbab7f7ea7ad910f56eaa65c87eaf2574d30df742019ea9ac92",
    ),
    (
        "teleprompter-concept",
        "d8a42232d19d87a23b1a2aacbc1970cae75bd0f0c7a3b523c701c5a2fa79762e",
    ),
)
M6_RESULT_PENDING_FIELDS = (
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
M6_LEDGER_TITLES = (
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
M6_LORE_TRAILER_KEYS = (
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
M6_NATIVE_REPLAY_PAIR_LABELS = (1, 2, 3, 4, 5, 7, 8, 9, 10)
M6_STAGE_RECONSTRUCTION_MARKERS = (
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
M6_PRIOR_LEDGER_PAIRS = (
    ("726c781f4fd09e0bdc69c37a0f424c3979451736", "401fa11f385fb3d56aaa4864d3a316853e59b4e3"),
    ("8acd1c19333bf4f5f9673409a4672773043f9ce8", "f1daca33ef87b24421fa4a6b38437cce8daa10f5"),
    ("dbb7db12b346936c2799f3980ba411925bb01d6a", "a202a88d27b3be1f9327b1b9843c21b7bba1710a"),
    ("980df38b6d18e4490ccaef185670cd23dba04e2f", "2c655f2dd58675822bb5c095db78ff67f3f41e9e"),
    ("db025cd6ff342f9c7d06eb9994593d41a270c143", "491a0d415512e08a91119abf4d24f96bb17b3869"),
    ("c70000807063c3a2a6e795e40917a6edc3878f61", "4876163282db70c9651dfa511602d027a4d45900"),
)

M6_M3_REQUIRED_PATHS = (
    "PrivatePresenterApp/Overlay/OverlayQuickControlsView.swift",
)

M6_M3_NAMED_TESTS = (
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

M6_M3_SOURCE_MARKERS = (
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

M6_M4_NAMED_TESTS = (
    "testResizeMatrixKeepsEveryPixelAndControlInsideRoundedSurface",
    "testToolbarNeverOverlapsBandOrFinalLine",
    "testHundredResizesPreserveAnchorAndAvoidTextReplacement",
    "testEveryHeaderAndResizeFrameRemainsContainedExactlyOnce",
    "testCompactTierDenseHitGridRoutesEveryControlBeforeResize",
    "testAllEightResizeOperationsRemainReachableOutsideControlsAtEveryTier",
)
M6_M4_SOURCE_MARKERS = (
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

M6_M5_VISUAL_REQUIRED_PATHS = (
    "PrivatePresenterAppTests/M6VisualTestSupport.swift",
)
M6_M5_VISUAL_NAMED_TESTS = (
    "testActualOverlayRenderMatchesIndependentSemanticBaseline",
    "testSemanticComparatorRejectsEveryNamedCorruption",
    "testIndependentContinuousMaskRejectsWrongRadiusAndStyle",
    "testRenderMatrixPreservesContainmentOpacityAndFocusGeometry",
    "testNativeRenderAttributesAndFramesRemainExplicit",
)
M6_M5_VISUAL_SOURCE_MARKERS = (
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

M6_REPAIR_NAMED_TESTS = (
    "testOffscreenQuickControlsUseFullRectangularTargetsWithCircularPaint",
    "testOffscreenProbeDoesNotOrderOrLeakApplicationWindows",
    "testOffscreenRootDispatchesEveryControlResizeAndTitleRouteAcrossTiers",
    "testOffscreenSettingsPressShowsExistingControllerExactlyOnceWithoutActivation",
    "testOffscreenLockedChromeLeavesSemanticsAndReaderStateUnchanged",
    "testDefaultUnlockedOffscreenHeaderOffersLockTeleprompter",
    "testPlaybackTargetsRespectExistingPresentationEligibility",
)
M6_REPAIR_SOURCE_MARKERS = (
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
M6_REPAIR_FORBIDDEN_MARKERS = (
    ("circular-hit-shape", "PrivatePresenterApp/Overlay/OverlayQuickControlsView.swift", ".contentShape(Circle())"),
    ("globally-ordered-test-window", "PrivatePresenterAppTests/M6VisualTestSupport.swift", "orderFrontRegardless()"),
    ("shared-test-window", "PrivatePresenterAppTests/M6VisualTestSupport.swift", "NSWindow("),
    ("stale-ax-query", "PrivatePresenterAppTests/M6VisualTestSupport.swift", "accessibilityChildren()"),
    ("duplicated-empty-policy", "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift", "state.scriptText.trimmingCharacters"),
)

M6_BAND_REPAIR_NAMED_TESTS = (
    "testCompactActiveBandUsesReservedReadingRectMidpoint",
    "testAttachedAttributeReconciliationRefreshesCachedBandWithoutReaderMutation",
    "testClipOriginRefreshUsesExactCachedTargetAndCoalescesAtLineBoundaries",
    "testCachedBandSelectionPreservesSortedMetricsAndFollowingTieBreakWithoutResort",
)
M6_BAND_REPAIR_SOURCE_MARKERS = (
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

M6_ORACLE_REPAIR_NAMED_TESTS = (
    "testActualRenderBufferUsesNamedSRGBEightBitPremultipliedRGBA",
    "testOffscreenTextKitRenderHostUsesAssertedTwoXBackingScale",
    "testSemanticOracleBandUsesTwoIndependentlyMeasuredTextKitFragmentHeights",
    "testCanonicalFrameworkMaskStaysLiteralIndependentAndMutationSensitive",
)
M6_ORACLE_REPAIR_SOURCE_MARKERS = (
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
M6_ORACLE_REPAIR_FORBIDDEN_MARKERS = (
    ("nonpremultiplied-alpha", ".alphaNonpremultiplied"),
    ("screen-dependent-scale", "NSScreen"),
    ("fixed-band-formula", "2 * (42 * 1.42) + 12"),
)

M6_HOSTED_EVIDENCE_REPAIR_NAMED_TESTS = (
    "testOffscreenQuickControlsUseFullRectangularTargetsWithCircularPaint",
    "testOffscreenProbeConfirmsPrivatePresenterBeforePlaybackMutation",
    "testOffscreenLockedChromeLeavesSemanticsAndReaderStateUnchanged",
)
M6_HOSTED_EVIDENCE_REPAIR_SOURCE_MARKERS = (
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
M6_HOSTED_EVIDENCE_REPAIR_FORBIDDEN_MARKERS = (
    ("fabricated-shield-state", "model.isShielded ="),
    ("fabricated-confirmation-state", "model.isSelectionConfirmed ="),
    ("globally-visible-window", "orderFrontRegardless()"),
    ("shared-app-window", "NSWindow("),
    ("stale-ax-traversal", "accessibilityChildren()"),
)

M6_M1_REQUIRED_PATHS = (
    "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift",
    "PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift",
)

M6_M1_NAMED_TESTS = (
    "testReferenceSurfaceUsesExactOpaqueNavyTokens",
    "testRoundedInteriorIsOpaqueOverWhiteAndBlack",
    "testNoTitleBarScrollbarGlowOrCompetingReaderFill",
)

M6_M1_SOURCE_MARKERS = (
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

M6_M2_NAMED_TESTS = (
    "testReaderUsesSystemTypographyAndReferenceSpacing",
    "testPersistedWeightMapsWithoutReplacingText",
    "testActiveBandUsesTwoCachedTextKit2LineFragmentsForEveryWeightAtDefaultAndLargeSizes",
    "testBandLineSelectionUsesNearestThenAdjacentWithFollowingTieBreak",
    "testActiveBandOneAndZeroFragmentFallbacksAndCompactClampDoNotClipGlyphs",
    "testBandMetricsCreateNoSecondTextLayoutManagerOrCacheOwner",
    "testLiteralTextAndBandContrastThresholds",
)

M6_M2_SOURCE_MARKERS = (
    ("effect-font-weight", "PrivatePresenterApp/App/AppEffect.swift", "fontWeight: TeleprompterFontWeight,", 1),
    ("model-persisted-weight", "PrivatePresenterApp/App/AppModel.swift", "fontWeight: preferences.fontWeight,", 2),
    ("adapter-connect-weight", "PrivatePresenterApp/App/DependencyContainer.swift", "fontWeight: model.preferences.fontWeight,", 1),
    ("reader-weight-parameter", "PrivatePresenterApp/Overlay/ReaderTextSystem.swift", "fontWeight: TeleprompterFontWeight = .regular,", 1),
    ("reader-weight-map", "PrivatePresenterApp/Overlay/ReaderTextSystem.swift", "case .regular: .regular\n        case .medium: .medium\n        case .semibold: .semibold", 1),
    ("reference-line-spacing", "PrivatePresenterApp/Overlay/ReaderTextSystem.swift", "paragraph.lineHeightMultiple = 1.42", 1),
    ("named-reading-color", "PrivatePresenterApp/Overlay/ReaderTextSystem.swift", ".foregroundColor: OverlayVisualTokens.readingText.appKitColor", 1),
    ("layout-authority", "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift", "struct OverlayLayoutMetrics: Equatable", 1),
    ("band-leading-token", "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift", "red: 130.0 / 255, green: 160.0 / 255, blue: 213.0 / 255, opacity: 0.28", 1),
    ("band-middle-token", "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift", "red: 113.0 / 255, green: 145.0 / 255, blue: 202.0 / 255, opacity: 0.35", 1),
    ("band-trailing-token", "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift", "red: 130.0 / 255, green: 160.0 / 255, blue: 213.0 / 255, opacity: 0.20", 1),
    ("band-accent-token", "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift", "red: 190.0 / 255, green: 211.0 / 255, blue: 248.0 / 255, opacity: 0.62", 1),
    ("band-radius", "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift", "static let activeBandRadius: CGFloat = 8", 1),
    ("line-measure-cap", "PrivatePresenterApp/Overlay/OverlayVisualTokens.swift", "min(1_050, max(0, size.width - 2 * effectiveReadingSideInset))", 1),
    ("cached-band-query", "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift", "func cachedActiveBandLineFragments(\n        viewportFraction: Double", 1),
    ("pure-band-selection", "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift", "static func selectActiveBandLineFragments(", 1),
    ("layout-before-band-query", "PrivatePresenterApp/Overlay/ReaderTextView.swift", "viewportAdapter.ensureLayout()\n        resolvedBandFragments = viewportAdapter.cachedActiveBandLineFragments(", 1),
    ("band-fallback", "PrivatePresenterApp/Overlay/ReaderTextView.swift", "2 * fallbackLineHeight + 12", 1),
    ("band-horizontal-expansion", "PrivatePresenterApp/Overlay/ReaderTextView.swift", "let bandMinX = max(0, metrics.effectiveReadingSideInset - 18)", 1),
    ("band-gradient-layer", "PrivatePresenterApp/Overlay/ReaderTextView.swift", "private let gradientLayer = CAGradientLayer()", 1),
)

M6_PREDECESSOR_PENDING_CLAIMS = (
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

M6_M5_HANDOFF_FILES = (
    "MAC-CONTINUATION.md",
    "m5-artifacts.sha256",
    "m5-review-red-source-files.sha256",
    "m5-source-files.sha256",
    "private-presenter-m5-review-red-source.tar",
    "private-presenter-m5-source.tar",
    "private-presenter-m5-wsl.bundle",
)

M6_FINAL_CHANGED_PATHS = (
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
    M6_RESULT_PATH,
)

M6_IMMUTABLE_SOURCE_PATHS = (
    "project.yml",
    "Packages/TeleprompterCore/Package.swift",
    "PrivatePresenterApp/Info.plist",
    "PrivatePresenterApp/Resources/PrivatePresenter.entitlements",
    "Config/Shared.xcconfig",
    "Config/Debug.xcconfig",
    "Config/Release.xcconfig",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ScriptDocument.swift",
    "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/PersistedSnapshot.swift",
)

M6_APPROVED_METADATA_TYPE_REPAIRS = {
    "project.yml": (
        b"        CFBundleVersion: 1\n",
        b'        CFBundleVersion: "1"\n',
    ),
    "PrivatePresenterApp/Info.plist": (
        b"\t<integer>1</integer>\n",
        b"\t<string>1</string>\n",
    ),
}




def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def uses_textkit2(source: str) -> bool:
    return "NSTextView(usingTextLayoutManager: true)" in source or all(
        marker in source
        for marker in ("NSTextContentStorage()", "NSTextLayoutManager()", "NSTextContainer()")
    )


def git(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args], cwd=ROOT, check=False, text=True, capture_output=True
    )


@lru_cache(maxsize=None)
def committed_bytes(commit: str, path: str) -> tuple[int, bytes]:
    result = subprocess.run(
        ["git", "show", f"{commit}:{path}"],
        cwd=ROOT,
        check=False,
        capture_output=True,
    )
    return result.returncode, result.stdout


def approved_metadata_repair_bytes(path: str, baseline: bytes) -> bytes:
    repair = M6_APPROVED_METADATA_TYPE_REPAIRS.get(path)
    if repair is None:
        return baseline
    old, new = repair
    return baseline.replace(old, new, 1) if baseline.count(old) == 1 else baseline


def phone_migration_active() -> bool:
    return (ROOT / "iPhoneApp/TeleprompterPhoneApp.swift").is_file()


def migrated_source_compatible(path: str, expected: str) -> bool:
    if path == "project.yml":
        return mac_project_compatible(read(path), expected)
    if path == "Packages/TeleprompterCore/Package.swift":
        return core_package_compatible(read(path))
    return read(path) == expected


def validate_plists() -> None:
    info_path = ROOT / "PrivatePresenterApp/Info.plist"
    entitlement_path = ROOT / "PrivatePresenterApp/Resources/PrivatePresenter.entitlements"
    with info_path.open("rb") as stream:
        info = plistlib.load(stream)
    with entitlement_path.open("rb") as stream:
        entitlements = plistlib.load(stream)
    if info.get("CFBundleDisplayName") != "Private Presenter":
        fail("Info.plist must set CFBundleDisplayName to Private Presenter")
    if not isinstance(info.get("CFBundleVersion"), str):
        fail("Info.plist CFBundleVersion must be a string")
    if entitlements.get("com.apple.security.app-sandbox") is not True:
        fail("App Sandbox must be enabled")
    prohibited = {
        "com.apple.security.network.client",
        "com.apple.security.network.server",
        "com.apple.security.automation.apple-events",
    }
    present = prohibited.intersection(entitlements)
    if present:
        fail(f"prohibited entitlements present: {sorted(present)}")


def validate_xcode_listing() -> None:
    if platform.system() != "Darwin" or not (ROOT / "PrivatePresenter.xcodeproj").exists():
        return
    result = subprocess.run(
        [
            "xcodebuild",
            "-list",
            "-json",
            "-project",
            "PrivatePresenter.xcodeproj",
        ],
        cwd=ROOT,
        check=False,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        fail(f"xcodebuild -list failed: {result.stderr.strip()}")
    listing = json.loads(result.stdout).get("project", {})
    expected_targets = {"PrivatePresenter", "PrivatePresenterAppTests", "PrivatePresenterUITests"}
    if not expected_targets.issubset(set(listing.get("targets", []))):
        fail("generated project is missing required targets")
    if "PrivatePresenter" not in listing.get("schemes", []):
        fail("generated project is missing shared PrivatePresenter scheme")


def validate_data_safety() -> None:
    violations: list[str] = []
    sensitive_name = re.compile(r"\b(document|title|text|contextBefore|contextAfter)\b")
    for path in (ROOT / "PrivatePresenterApp").rglob("*.swift"):
        for line_number, raw_line in enumerate(
            path.read_text(encoding="utf-8").splitlines(), start=1
        ):
            code = raw_line.split("//", 1)[0]
            if any(re.search(pattern, code) for pattern in DATA_SAFETY_PATTERNS):
                violations.append(f"{path.relative_to(ROOT)}:{line_number}")
            if "\\(" in code and sensitive_name.search(code):
                violations.append(f"{path.relative_to(ROOT)}:{line_number}")
            if "appendingPathComponent" in code and sensitive_name.search(code):
                violations.append(f"{path.relative_to(ROOT)}:{line_number}")
    if violations:
        fail("unsafe local-data exposure marker in product source: " + ", ".join(violations))


def validate_historical_result_prefix() -> None:
    baseline = git(
        "show",
        "940e1821f36c4125b0f81f623a6d24a015c22dcc:"
        "docs/validation/overlay-proof-result.md",
    )
    if baseline.returncode != 0:
        fail("historical overlay result baseline is unavailable")
    baseline_bytes = baseline.stdout.encode("utf-8")
    current = (ROOT / "docs/validation/overlay-proof-result.md").read_bytes()
    import hashlib

    if len(baseline_bytes) != 14_486:
        fail("historical overlay result baseline length changed")
    if hashlib.sha256(baseline_bytes).hexdigest() != (
        "e6f63a252ead5e3fc16db43f94ecf0b2e8c31db055da0b26715ba60a2295b3da"
    ):
        fail("historical overlay result baseline hash changed")
    if not current.startswith(baseline_bytes):
        fail("overlay result no longer begins with the immutable historical prefix")


def validate_m0_prohibited_surfaces() -> None:
    violations: list[str] = []
    prohibited = (
        r"\bNSApp\.activate\s*\(",
        r"\bNSRunningApplication\b[^\n]*\.activate\s*\(",
        r"\bmakeKeyAndOrderFront\s*\(",
        r"\.screenSaver\b",
        r"\bCGWindowLevelForKey\s*\(",
        r"\bGetEventDispatcherTarget\s*\(",
        r"\bperformWindowDrag\s*\(",
        r"\bNSWindow\.Level\s*\(\s*rawValue",
        r"\bstyleMask[^\n]*(?:insert|formUnion)[^\n]*\.resizable",
        r"\bstyleMask\s*[:=][^\n]*\.resizable",
        r"\b(?:AXUIElement|AXObserver|AXIsProcessTrusted)\b",
        r"\bimport\s+ApplicationServices\b",
    )
    for path in (ROOT / "PrivatePresenterApp").rglob("*.swift"):
        for line_number, raw_line in enumerate(
            path.read_text(encoding="utf-8").splitlines(), start=1
        ):
            code = raw_line.split("//", 1)[0]
            if any(re.search(pattern, code) for pattern in prohibited):
                violations.append(f"{path.relative_to(ROOT)}:{line_number}")
    hot_key_source = read("PrivatePresenterApp/Services/DiagnosticHotKeyService.swift")
    if "GetApplicationEventTarget()" not in hot_key_source:
        violations.append("DiagnosticHotKeyService.swift:application-target-missing")
    for marker in ("kVK_ANSI_H", "kVK_ANSI_L", "Control-Option-H", "Control-Option-L"):
        if marker not in hot_key_source:
            violations.append(f"DiagnosticHotKeyService.swift:missing-{marker}")
    panel_source = read("PrivatePresenterApp/Overlay/TeleprompterPanel.swift")
    level_cases = re.findall(r"^\s*case\s+(\w+)\s*$", panel_source, re.MULTILINE)
    allowed_level_cases = {"floating", "statusBar", "front", "frontRegardless"}
    unexpected_level_cases = set(level_cases).difference(allowed_level_cases)
    if unexpected_level_cases:
        violations.append("TeleprompterPanel.swift:unexpected-bounded-enum-case")
    if violations:
        fail("prohibited M0 behavior marker in product source: " + ", ".join(violations))


def validate_m2_source() -> list[str]:
    violations: list[str] = []
    m4_or_later_source = (
        ROOT / "PrivatePresenterApp/Menu/StatusItemController.swift"
    ).is_file()
    missing_paths = [path for path in M2_REQUIRED_PATHS if not (ROOT / path).is_file()]
    violations.extend(f"missing-path:{path}" for path in missing_paths)

    test_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for root in (
            ROOT / "Packages/TeleprompterCore/Tests",
            ROOT / "PrivatePresenterAppTests",
        )
        for path in root.rglob("*.swift")
    )
    superseded_m2_ui_tests = {
        "testM2FocusModeExplainsM4AndDoesNotChangeChrome",
        "testM2PreservesStatusBarFrontRegardlessAndPermanentNonKeyNonMain",
    }
    violations.extend(
        f"missing-test:{name}"
        for name in M2_NAMED_TESTS
        if name not in test_sources
        and not (m4_or_later_source and name in superseded_m2_ui_tests)
    )

    production_files = list((ROOT / "PrivatePresenterApp").rglob("*.swift"))
    for path in production_files:
        source = path.read_text(encoding="utf-8")
        for pattern in M2_PROHIBITED_PATTERNS:
            if (
                m4_or_later_source
                and pattern == "NSStatusItem"
                and path.relative_to(ROOT).as_posix()
                == "PrivatePresenterApp/Menu/StatusItemController.swift"
            ):
                continue
            if pattern in source:
                violations.append(f"prohibited:{pattern}:{path.relative_to(ROOT)}")

    app_model = read("PrivatePresenterApp/App/AppModel.swift")
    if app_model.count("final class AppModel") != 1:
        violations.append("authority:AppModel-count")
    if "@MainActor\n@Observable\nfinal class AppModel" not in app_model:
        violations.append("authority:AppModel-main-actor")

    app_sources = "\n".join(path.read_text(encoding="utf-8") for path in production_files)
    if app_sources.count("TeleprompterPanel(contentRect:") != 1:
        violations.append("authority:panel-construction-count")

    editor_source = read("PrivatePresenterApp/Controller/EditorTextSystem.swift")
    reader_source = read("PrivatePresenterApp/Overlay/ReaderTextSystem.swift")
    if not uses_textkit2(editor_source):
        violations.append("textkit:editor-not-textkit2")
    if not uses_textkit2(reader_source):
        violations.append("textkit:reader-not-textkit2")
    if "private(set) var isAwaitingResync" not in reader_source:
        violations.append("reader:resync-latch-missing")
    if "incrementalMutationCount" not in reader_source or "fullReplacementCount" not in reader_source:
        violations.append("reader:mutation-instrumentation-missing")

    controller_source = read("PrivatePresenterApp/Controller/ControllerView.swift")
    m3_source_present = all(
        (ROOT / path).is_file()
        for path in (
            "Packages/TeleprompterCore/Sources/TeleprompterCore/Scrolling/ScrollEngine.swift",
            "PrivatePresenterApp/Overlay/ScrollSessionController.swift",
            "PrivatePresenterAppTests/ScrollSessionControllerTests.swift",
        )
    )
    if m3_source_present:
        control_markers = (
            'Button("Start") { dispatch(.start) }',
            'Button("Pause") { dispatch(.pause) }',
            'Button("Restart") { dispatch(.restart) }',
            'Button("Back") { dispatch(.back) }',
            'Button("Forward") { dispatch(.forward) }',
        )
        if m4_or_later_source:
            control_markers += ('accessibilityEntry("privatePresenter.focusMode")',)
        else:
            control_markers += (
                'Toggle("Focus Mode", isOn: .constant(false)).disabled(true)',
            )
        for marker in control_markers:
            if marker not in controller_source:
                violations.append(f"controller:missing-m3-marker:{marker}")
    else:
        for marker in (
            'Button("Start") {}.disabled(true)',
            'Button("Pause") {}.disabled(true)',
            'Button("Restart") {}.disabled(true)',
            'Toggle("Focus Mode", isOn: .constant(false)).disabled(true)',
        ):
            if marker not in controller_source:
                violations.append(f"controller:missing-disabled-marker:{marker}")
    for prohibited_dispatch in (
        "model.send(.start)",
        "model.send(.togglePlayback)",
        "model.send(.restart)",
    ):
        if prohibited_dispatch in controller_source:
            violations.append(f"controller:future-dispatch:{prohibited_dispatch}")

    if "static let currentSchemaVersion = 1" not in read(
        "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/PersistedSnapshot.swift"
    ):
        violations.append("schema:persisted-snapshot-version")
    document_path = "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ScriptDocument.swift"
    if "static let currentSchemaVersion = 1" not in read(
        PORTABLE_MOVES[document_path] if phone_migration_active() else document_path
    ):
        violations.append("schema:script-document-version")

    snapshot_store_baseline = git(
        "show",
        "d17e74a95f8e4b29dd691b911eb1f775421e2b30:"
        "PrivatePresenterApp/Services/SnapshotStore.swift",
    )
    if snapshot_store_baseline.returncode != 0:
        violations.append("snapshot-store:planning-baseline-unavailable")
    elif snapshot_store_baseline.stdout != read("PrivatePresenterApp/Services/SnapshotStore.swift"):
        violations.append("snapshot-store:production-source-changed")

    return violations


def validate_m3_source() -> list[str]:
    violations: list[str] = []
    m4_or_later_source = (
        ROOT / "PrivatePresenterApp/Menu/StatusItemController.swift"
    ).is_file()
    # Keep this inventory explicit: M3 may add its validator contract, but its
    # controlled-Mac result is forbidden until native/package/physical evidence exists.
    missing_paths = [path for path in M3_REQUIRED_PATHS if not (ROOT / path).is_file()]
    violations.extend(f"missing-path:{path}" for path in missing_paths)

    swift_test_paths = [
        path.relative_to(ROOT).as_posix()
        for root in (ROOT / "Packages/TeleprompterCore/Tests", ROOT / "PrivatePresenterAppTests")
        for path in root.rglob("*.swift")
    ]
    test_sources = "\n".join(read(path) for path in swift_test_paths)
    violations.extend(
        f"missing-test:{name}"
        for name in (*M3_CANONICAL_NAMED_TESTS, *M3_ADDED_NAMED_TESTS)
        if name not in test_sources
    )

    production_paths = [
        path.relative_to(ROOT).as_posix()
        for root in (ROOT / "Packages/TeleprompterCore/Sources", ROOT / "PrivatePresenterApp")
        for path in root.rglob("*.swift")
    ]
    production_sources = {path: read(path) for path in production_paths}
    if phone_migration_active():
        for old, new in PORTABLE_MOVES.items():
            if new in production_sources:
                production_sources[old] = production_sources[new]
    for path, text in production_sources.items():
        for pattern in M3_PROHIBITED_PATTERNS:
            if (
                m4_or_later_source
                and pattern == "NSStatusItem"
                and path == "PrivatePresenterApp/Menu/StatusItemController.swift"
            ):
                continue
            if pattern in text:
                violations.append(f"prohibited:{pattern}:{path}")

    app_sources = {
        path: text
        for path, text in production_sources.items()
        if path.startswith("PrivatePresenterApp/")
    }
    joined_app_sources = "\n".join(app_sources.values())
    if joined_app_sources.count("final class AppModel") != 1:
        violations.append("authority:AppModel-count")
    if joined_app_sources.count("TeleprompterPanel(contentRect:") != 1:
        violations.append("authority:panel-construction-count")
    if joined_app_sources.count("ScrollSessionController(") != 1:
        violations.append("authority:scroll-session-construction-count")

    app_model_path = "PrivatePresenterApp/App/AppModel.swift"
    app_model = app_sources[app_model_path]
    if "@MainActor\n@Observable\nfinal class AppModel" not in app_model:
        violations.append("authority:AppModel-main-actor")
    if "struct ScrollSessionGeneration" not in app_model or "fileprivate init" not in app_model:
        violations.append("authority:generation-issuer")
    for path, text in app_sources.items():
        if path != app_model_path and "ScrollSessionGeneration()" in text:
            violations.append(f"authority:generation-issued-outside-AppModel:{path}")

    editor = app_sources["PrivatePresenterApp/Controller/EditorTextSystem.swift"]
    reader = app_sources["PrivatePresenterApp/Overlay/ReaderTextSystem.swift"]
    adapter = app_sources["PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift"]
    if not uses_textkit2(editor):
        violations.append("textkit:editor-not-textkit2")
    if not uses_textkit2(reader):
        violations.append("textkit:reader-not-textkit2")
    for marker in ("textLayoutManager", "ensureLayout(for:", "enumerateTextLayoutFragments"):
        if marker not in adapter:
            violations.append(f"textkit:adapter-missing:{marker}")

    snapshot = production_sources[
        "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/PersistedSnapshot.swift"
    ]
    document = production_sources[
        "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ScriptDocument.swift"
    ]
    if "static let currentSchemaVersion = 1" not in snapshot:
        violations.append("schema:persisted-snapshot-version")
    if "static let currentSchemaVersion = 1" not in document:
        violations.append("schema:script-document-version")

    runtime = app_sources["PrivatePresenterApp/App/AppRuntime.swift"]
    dependency_container = app_sources["PrivatePresenterApp/App/DependencyContainer.swift"]
    panel = app_sources["PrivatePresenterApp/Overlay/TeleprompterPanel.swift"]
    if "proofLevel: OverlayPanelLevel = .statusBar" not in runtime:
        violations.append("panel:status-bar-default")
    if "orderingMode: OverlayPanelOrderingMode = .frontRegardless" not in dependency_container:
        violations.append("panel:front-regardless-default")
    if m4_or_later_source:
        if (
            "override var canBecomeKey: Bool { !isOverlayLocked && NSApp.isActive }"
            not in panel
        ):
            violations.append("panel:permanent-non-key")
    elif "override var canBecomeKey: Bool { false }" not in panel:
        violations.append("panel:permanent-non-key")
    if "override var canBecomeMain: Bool { false }" not in panel:
        violations.append("panel:permanent-non-main")

    clock = app_sources["PrivatePresenterApp/Overlay/DisplayLinkFrameClock.swift"]
    clock_markers = (
        "readerView.window != nil",
        "readerView.window?.screen != nil",
        "readerView.displayLink(",
        "link.timestamp",
        "RunLoop.main",
        "forMode: .common",
        "link.invalidate()",
    )
    for marker in clock_markers:
        if marker not in clock:
            label = {
                "link.timestamp": "clock:timestamp",
                "forMode: .common": "clock:common-run-loop",
            }.get(marker, f"clock:missing:{marker}")
            violations.append(label)
    if "targetTimestamp" in clock:
        violations.append("clock:target-timestamp")
    if "Date(" in clock or "Date." in clock:
        violations.append("clock:wall-time")

    session = app_sources["PrivatePresenterApp/Overlay/ScrollSessionController.swift"]
    for marker in ("model.send(", "@Observable", "withObservationTracking"):
        if marker in session:
            violations.append("hot-path:model-publication")
            break
    if "Task {" in session or "DispatchQueue" in session:
        violations.append("hot-path:asynchronous-session")

    controller = app_sources["PrivatePresenterApp/Controller/ControllerView.swift"]
    controller_markers = (
        'Button("Start") { dispatch(.start) }',
        'Button("Pause") { dispatch(.pause) }',
        'Button("Restart") { dispatch(.restart) }',
        'Button("Back") { dispatch(.back) }',
        'Button("Forward") { dispatch(.forward) }',
    )
    if m4_or_later_source:
        controller_markers += ('accessibilityEntry("privatePresenter.focusMode")',)
    else:
        controller_markers += (
            'Toggle("Focus Mode", isOn: .constant(false)).disabled(true)',
        )
    for marker in controller_markers:
        if marker not in controller:
            violations.append(f"controller:missing-m3-marker:{marker}")

    project_baseline = git("show", f"{M3_BASELINE}:project.yml")
    if project_baseline.returncode != 0:
        violations.append("dependency:project-baseline-unavailable")
    elif approved_metadata_repair_bytes(
        "project.yml", project_baseline.stdout.encode("utf-8")
    ).decode("utf-8") != read("project.yml") and not (phone_migration_active() and mac_project_compatible(
        read("project.yml"), approved_metadata_repair_bytes("project.yml", project_baseline.stdout.encode("utf-8")).decode("utf-8"))):
        violations.append("dependency:project-yml-changed")
    package_path = "Packages/TeleprompterCore/Package.swift"
    package_baseline = git("show", f"{M3_BASELINE}:{package_path}")
    if package_baseline.returncode != 0:
        violations.append("dependency:package-baseline-unavailable")
    elif package_baseline.stdout != read(package_path) and not (phone_migration_active() and core_package_compatible(read(package_path))):
        violations.append("dependency:package-swift-changed")

    project = read("project.yml")
    for dependency in M3_ALLOWED_PACKAGE_DEPENDENCIES:
        if dependency not in project:
            violations.append(f"dependency:missing-allowed:{dependency}")

    return violations


def validate_m4_source() -> list[str]:
    violations: list[str] = []
    missing_paths = [path for path in M4_REQUIRED_PATHS if not (ROOT / path).is_file()]
    violations.extend(f"missing-path:{path}" for path in missing_paths)

    test_roots = (
        ROOT / "Packages/TeleprompterCore/Tests",
        ROOT / "PrivatePresenterAppTests",
        ROOT / "PrivatePresenterUITests",
    )
    test_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for root in test_roots
        for path in root.rglob("*.swift")
    )
    violations.extend(
        f"missing-test:{name}"
        for name in (*M4_CANONICAL_NAMED_TESTS, *M4_ADDED_NAMED_TESTS)
        if name not in test_sources
    )

    production_paths = [
        path.relative_to(ROOT).as_posix()
        for root in (ROOT / "Packages/TeleprompterCore/Sources", ROOT / "PrivatePresenterApp")
        for path in root.rglob("*.swift")
    ]
    production_sources = {path: read(path) for path in production_paths}
    if phone_migration_active():
        for old, new in PORTABLE_MOVES.items():
            if new in production_sources:
                production_sources[old] = production_sources[new]
    for path, text in production_sources.items():
        for pattern in M4_PROHIBITED_PATTERNS:
            if pattern in text:
                violations.append(f"prohibited:{pattern}:{path}")

    app_sources = {
        path: text
        for path, text in production_sources.items()
        if path.startswith("PrivatePresenterApp/")
    }
    joined_app_sources = "\n".join(app_sources.values())
    if joined_app_sources.count("final class AppModel") != 1:
        violations.append("authority:AppModel-count")
    if joined_app_sources.count("@Observable") != 1:
        violations.append("authority:observable-store-count")
    if joined_app_sources.count("TeleprompterPanel(contentRect:") != 1:
        violations.append("authority:panel-construction-count")
    if joined_app_sources.count("NSStatusBar.system.statusItem(") != 1:
        violations.append("authority:status-item-construction-count")
    product_hot_keys = app_sources.get(
        "PrivatePresenterApp/Services/CarbonHotKeyService.swift", ""
    )
    if product_hot_keys.count("InstallEventHandler(") != 1:
        violations.append("authority:product-handler-install-count")
    if joined_app_sources.count("ScrollSessionController(") != 1:
        violations.append("authority:scroll-session-construction-count")

    app_model = app_sources.get("PrivatePresenterApp/App/AppModel.swift", "")
    if "@MainActor\n@Observable\nfinal class AppModel" not in app_model:
        violations.append("authority:AppModel-main-actor")
    for marker in (
        "RegisterEventHotKey(",
        "UnregisterEventHotKey(",
        "GetApplicationEventTarget()",
        "RemoveEventHandler(",
        "action.stableIndex + 1",
    ):
        source = (
            product_hot_keys
            if marker != "action.stableIndex + 1"
            else app_sources.get("PrivatePresenterApp/Interfaces/HotKeyRegistering.swift", "")
        )
        if marker not in source:
            violations.append(f"hotkey:missing:{marker}")
    for marker in (
        "case cleanupUnknown",
        "case degradedClean",
        "case reconfiguring",
        "case rollingBack",
        "static let cleanupUnknownMessage",
    ):
        if marker not in product_hot_keys:
            violations.append(f"hotkey:transaction-marker:{marker}")

    runtime = app_sources.get("PrivatePresenterApp/App/AppRuntime.swift", "")
    application = app_sources.get("PrivatePresenterApp/App/PrivatePresenterApp.swift", "")
    if "case product" not in read("PrivatePresenterApp/Interfaces/HotKeyRegistering.swift"):
        violations.append("hotkey:product-mode")
    if "case legacyDiagnostic" not in read("PrivatePresenterApp/Interfaces/HotKeyRegistering.swift"):
        violations.append("hotkey:legacy-mode")
    if "case .product:" not in runtime or "case .legacyDiagnostic:" not in runtime:
        violations.append("hotkey:exclusive-runtime-routing")
    if "PRIVATE_PRESENTER_EVIDENCE_COMMIT" not in application:
        violations.append("hotkey:bounded-legacy-proof-mode")

    panel = app_sources.get("PrivatePresenterApp/Overlay/TeleprompterPanel.swift", "")
    if "override var canBecomeKey: Bool { !isOverlayLocked && NSApp.isActive }" not in panel:
        violations.append("panel:dynamic-key-eligibility")
    if "override var canBecomeMain: Bool { false }" not in panel:
        violations.append("panel:permanent-non-main")
    overlay_root = app_sources.get(
        "PrivatePresenterApp/Overlay/OverlayRootView.swift", ""
    )
    if "ignoresMouseEvents = false" not in panel or any(
        marker not in overlay_root
        for marker in (
            "lockedInteractionBlocker",
            "lockedUnlockTarget(model: model, metrics: metrics)",
            '"privatePresenter.headerLock"',
        )
    ):
        violations.append("panel:locked-unlock-target")
    if "proofLevel: OverlayPanelLevel = .statusBar" not in runtime:
        violations.append("panel:status-bar-default")
    dependency_container = app_sources.get(
        "PrivatePresenterApp/App/DependencyContainer.swift", ""
    )
    if "orderingMode: OverlayPanelOrderingMode = .frontRegardless" not in dependency_container:
        violations.append("panel:front-regardless-default")

    focus_machine = production_sources.get(
        "Packages/TeleprompterCore/Sources/TeleprompterCore/Focus/FocusChromeStateMachine.swift",
        "",
    )
    if ".scheduleHide(after: 2, token: token)" not in focus_machine:
        violations.append("focus:two-second-deadline")
    pointer = app_sources.get("PrivatePresenterApp/Overlay/PointerPresenceMonitor.swift", "")
    if "samplingInterval: TimeInterval = 0.1" not in pointer:
        violations.append("focus:pointer-sampling-interval")
    if "NSEvent.mouseLocation" not in dependency_container:
        violations.append("focus:location-only-provider")
    if "accessibilityDisplayShouldReduceMotion" not in dependency_container:
        violations.append("focus:reduce-motion-provider")

    menu = app_sources.get("PrivatePresenterApp/Menu/StatusItemController.swift", "")
    required_menu_titles = (
        '("Show Controller", #selector(showController))',
        '("Start", #selector(togglePlayback))',
        '("Show Teleprompter", #selector(toggleVisibility))',
        '("Lock", #selector(toggleLock))',
        '("Quit", #selector(requestQuit))',
    )
    if menu.count("NSMenuItem(title:") != 1 or any(
        marker not in menu for marker in required_menu_titles
    ):
        violations.append("menu:exact-five-actions")
    for marker in (
        "case 0: command = .showController",
        "case 1: command = .togglePlayback",
        "case 2: command = .toggleVisibility",
        "case 3: command = .toggleLock",
        "case 4: command = .requestQuit",
    ):
        if marker not in menu:
            violations.append("menu:typed-command-map")
            break
    if any(marker in menu for marker in ("model.document.title", "model.document.text")):
        violations.append("menu:private-content-reference")

    lifecycle = app_sources.get("PrivatePresenterApp/App/AppLifecycleCoordinator.swift", "")
    ordered_lifecycle_markers = (
        "record(.rejectMutations)",
        "record(.pauseAndCapture)",
        "record(.hideAndShield)",
        "record(.stagePausedSnapshot)",
        "record(.flushPausedSnapshot)",
        "record(.enterQuiescence)",
        "record(.unregisterHotKeys)",
        "record(.stopFocusPointerDisplay)",
        "record(.teardownScrollSession)",
        "record(.removeStatusItem)",
        "record(.closeController)",
        "record(.terminateReady)",
    )
    lifecycle_positions = [lifecycle.find(marker) for marker in ordered_lifecycle_markers]
    if any(position < 0 for position in lifecycle_positions) or lifecycle_positions != sorted(
        lifecycle_positions
    ):
        violations.append("lifecycle:ordered-markers")
    for marker in (
        "model.send(.cancelTerminationAttempt)",
        "record(.flushFailed)",
        "if completed { return true }",
    ):
        if marker not in lifecycle:
            violations.append(f"lifecycle:missing:{marker}")

    snapshot_path = (
        "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/"
        "PersistedSnapshot.swift"
    )
    if "static let currentSchemaVersion = 1" not in production_sources.get(snapshot_path, ""):
        violations.append("schema:persisted-snapshot-version")
    document_path = (
        "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ScriptDocument.swift"
    )
    if "static let currentSchemaVersion = 1" not in production_sources.get(document_path, ""):
        violations.append("schema:script-document-version")
    if "static let documentBottomPadding = 64.0" not in app_sources.get(
        "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift", ""
    ):
        violations.append("reader:bottom-padding")
    for path in (
        "PrivatePresenterApp/Controller/EditorTextSystem.swift",
        "PrivatePresenterApp/Overlay/ReaderTextSystem.swift",
    ):
        if not uses_textkit2(app_sources.get(path, "")):
            violations.append(f"textkit:not-textkit2:{path}")

    protected_sources = (
        "project.yml",
        "Packages/TeleprompterCore/Package.swift",
        "PrivatePresenterApp/Info.plist",
        "PrivatePresenterApp/Resources/PrivatePresenter.entitlements",
        "PrivatePresenterApp/Services/SnapshotStore.swift",
    )
    for path in protected_sources:
        baseline = git("show", f"{M4_BASELINE}:{path}")
        label = {
            "project.yml": "dependency:project-yml-changed",
            "Packages/TeleprompterCore/Package.swift": "dependency:package-swift-changed",
            "PrivatePresenterApp/Resources/PrivatePresenter.entitlements": "entitlement:changed",
        }.get(path, f"protected-source:{path}")
        expected = approved_metadata_repair_bytes(
            path, baseline.stdout.encode("utf-8")
        ).decode("utf-8")
        if baseline.returncode != 0 or not (migrated_source_compatible(path, expected) if phone_migration_active() else expected == read(path)):
            violations.append(label)
    entitlements = read("PrivatePresenterApp/Resources/PrivatePresenter.entitlements")
    if any(
        marker in entitlements
        for marker in (
            "com.apple.security.network.client",
            "com.apple.security.network.server",
            "com.apple.security.automation.apple-events",
            "com.apple.security.device.audio-input",
            "com.apple.security.device.camera",
        )
    ):
        violations.append("entitlement:non-sandbox-surface")

    return violations


def validate_m5_source() -> list[str]:
    """Validate the complete M5 source, evidence, and Mac-replay boundary."""
    violations: list[str] = []

    missing_paths = [
        path for path in M5_FULL_REQUIRED_PATHS if not (ROOT / path).is_file()
    ]
    violations.extend(f"missing-path:{path}" for path in missing_paths)

    test_roots = (
        ROOT / "Packages/TeleprompterCore/Tests",
        ROOT / "PrivatePresenterAppTests",
        ROOT / "PrivatePresenterUITests",
    )
    swift_test_sources = "\n".join(
        read(path.relative_to(ROOT).as_posix())
        for root in test_roots
        for path in root.rglob("*.swift")
    )
    required_test_names = (
        *M5_ACCESSIBILITY_NAMED_TESTS,
        *M5_LIFECYCLE_NAMED_TESTS,
        *M5_SIGNPOST_NAMED_TESTS,
        *M5_PERFORMANCE_NAMED_TESTS,
        *M5_INDEPENDENT_REVIEW_NAMED_TESTS,
    )
    for name in required_test_names:
        if re.search(rf"\bfunc\s+{re.escape(name)}\b", swift_test_sources) is None:
            violations.append(f"missing-test:{name}")

    ancestry = git("merge-base", "--is-ancestor", M5_BASELINE, "HEAD")
    if ancestry.returncode != 0:
        violations.append("ancestry:m5-plan-baseline-not-ancestor")

    binary_suffixes = {".png"}
    for path in M5_PROTECTED_PATHS:
        baseline_returncode, baseline_bytes = committed_bytes(M5_BASELINE, path)
        if Path(path).suffix in binary_suffixes:
            current = (ROOT / path).read_bytes() if (ROOT / path).is_file() else None
            matches = baseline_returncode == 0 and baseline_bytes == current
        else:
            matches = (
                baseline_returncode == 0
                and (ROOT / path).is_file()
                and baseline_bytes.decode("utf-8") == read(path)
            )
        if not matches:
            violations.append(f"protected-byte:{path}")

    for contract_class, contracts in (
        ("fixture", M5_FIXTURE_CONTRACT_MARKERS),
        ("performance", M5_PERFORMANCE_CONTRACT_MARKERS),
        ("signpost", M5_SIGNPOST_STATIC_MARKERS),
    ):
        for label, path, marker in contracts:
            if not (ROOT / path).is_file():
                violations.append(f"{contract_class}:missing-marker:{label}")
                continue
            expected_count = M5_CONTRACT_MARKER_COUNTS[(contract_class, label)]
            if read(path).count(marker) != expected_count:
                violations.append(f"{contract_class}:missing-marker:{label}")

    for label, path, markers in M5_ORDERED_CONTRACT_MARKERS:
        if not (ROOT / path).is_file():
            violations.append(f"order:{label}")
            continue
        source = read(path)
        if any(
            source.count(marker) != M5_ORDER_MARKER_COUNTS[(label, marker)]
            for marker in markers
        ):
            violations.append(f"order:{label}")
            continue
        cursor = -1
        for marker in markers:
            cursor = source.find(marker, cursor + 1)
            if cursor < 0:
                violations.append(f"order:{label}")
                break

    production_paths = [
        path.relative_to(ROOT).as_posix()
        for root in (ROOT / "Packages/TeleprompterCore/Sources", ROOT / "PrivatePresenterApp")
        for path in root.rglob("*.swift")
    ]
    production_sources = {path: read(path) for path in production_paths}
    if phone_migration_active():
        for old, new in PORTABLE_MOVES.items():
            if new in production_sources:
                production_sources[old] = production_sources[new]
    app_sources = {
        path: source
        for path, source in production_sources.items()
        if path.startswith("PrivatePresenterApp/")
    }
    joined_app_sources = "\n".join(app_sources.values())

    accessibility_source = app_sources.get(
        "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift", ""
    )
    if accessibility_source.count(".accessibilityHint(Text(entry.help))") != 1:
        violations.append("accessibility:missing-help-bridge")
    overlay_chrome_source = app_sources.get(
        "PrivatePresenterApp/Overlay/OverlayChromeView.swift", ""
    )
    if overlay_chrome_source.count(".frame(minWidth: 44, minHeight: 44)") != 3:
        violations.append("accessibility:missing-44-point-frame")

    m6_markers = {"LinearGradient(", "#34466F", "#202B4B", "#F7F8FC"}
    found_m6_surface = (ROOT / "docs/validation/visual-result.md").exists()
    for path, source in production_sources.items():
        for pattern in M5_PROHIBITED_PATTERNS:
            if pattern in source:
                violations.append(f"prohibited:{pattern}:{path}")
                found_m6_surface = found_m6_surface or pattern in m6_markers

        if path != "PrivatePresenterApp/Services/PerformanceSignposter.swift" and any(
            marker in source
            for marker in (
                "import OS",
                "OSSignposter",
                "OSSignpostIntervalState",
                "OSSignpostType",
            )
        ):
            violations.append(f"signpost:OS-boundary:{path}")

        for line_number, line in enumerate(source.splitlines(), start=1):
            if "metadata:" in line:
                violations.append(f"signpost:arbitrary-metadata:{path}:{line_number}")
            if "performanceSignposter" not in line:
                continue
            if any(
                marker in line
                for marker in (
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
            ):
                violations.append(f"signpost:private-sentinel:{path}:{line_number}")

    if found_m6_surface:
        violations.append("scope:m6-visual-polish")

    interface_path = "PrivatePresenterApp/Interfaces/PerformanceSignposting.swift"
    interface = production_sources.get(interface_path, "")

    def enum_values(enum_name: str) -> tuple[str, ...]:
        match = re.search(
            rf"enum\s+{re.escape(enum_name)}\b[^{{]*\{{(.*?)^\}}",
            interface,
            re.MULTILINE | re.DOTALL,
        )
        if match is None:
            return ()
        values: list[str] = []
        for name, raw_value in re.findall(
            r'^\s*case\s+(\w+)(?:\s*=\s*"([^"]+)")?\s*$',
            match.group(1),
            re.MULTILINE,
        ):
            values.append(raw_value or name)
        return tuple(values)

    closed_enums = (
        ("PerformanceSignpostCategory", M5_SIGNPOST_CATEGORIES),
        ("PerformanceSignpostOperation", M5_SIGNPOST_OPERATIONS),
        ("PerformanceSignpostOutcome", M5_SIGNPOST_OUTCOMES),
        ("PerformanceSignpostReason", M5_SIGNPOST_REASONS),
    )
    for enum_name, expected in closed_enums:
        if enum_values(enum_name) != tuple(expected):
            violations.append(f"signpost:closed-metadata:{enum_name}")

    scoped_token_markers = (
        "PerformanceSignpostToken",
        "PerformanceIntervalToken",
        "OSSignpostIntervalState",
    )
    token_forbidden_paths = {
        "PrivatePresenterApp/App/AppEffect.swift",
        "PrivatePresenterApp/Services/SnapshotStore.swift",
        "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift",
    }
    for path, source in production_sources.items():
        if path.startswith("Packages/TeleprompterCore/") or path in token_forbidden_paths:
            if any(marker in source for marker in scoped_token_markers):
                violations.append(f"signpost:token-crosses-boundary:{path}")

    allowed_private_surface_counts = {
        (
            "PrivatePresenterApp/Services/SnapshotStore.swift",
            "revision=",
        ): 1,
        (
            "PrivatePresenterApp/Services/SnapshotStore.swift",
            "url=",
        ): 1,
        (
            "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift",
            "document.text",
        ): 1,
        (
            "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift",
            "document.title",
        ): 1,
    }
    private_surface_paths = (
        "PrivatePresenterApp/App/AppEffect.swift",
        "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ScriptDocument.swift",
        "PrivatePresenterApp/Services/SnapshotStore.swift",
        "PrivatePresenterApp/Accessibility/PresenterAccessibility.swift",
    )
    for path in private_surface_paths:
        source = production_sources.get(path, "")
        for marker in M5_PRIVATE_SURFACE_MARKERS:
            allowed = allowed_private_surface_counts.get((path, marker), 0)
            if source.count(marker) > allowed:
                violations.append(f"privacy:private-surface:{path}:{marker}")

    for path in M5_PENDING_EVIDENCE_PATHS:
        if not (ROOT / path).is_file():
            continue
        lines = read(path).splitlines()
        for marker in M5_PENDING_TEMPLATE_MARKERS:
            if marker not in lines:
                violations.append(f"evidence:missing-marker:{path}:{marker}")
        if "Status: PENDING" not in lines:
            violations.append(f"evidence:status-not-pending:{path}")

    callback_evidence_path = "docs/validation/m5-display-crash-quit-result.md"
    if (ROOT / callback_evidence_path).is_file():
        callback_evidence_lines = read(callback_evidence_path).splitlines()
        for marker in M5_REVIEW_PENDING_TEMPLATE_MARKERS:
            if marker not in callback_evidence_lines:
                violations.append(
                    f"evidence:missing-marker:{callback_evidence_path}:{marker}"
                )

    history_result = git("log", "--format=%H%x09%P%x09%s", f"{M5_BASELINE}..HEAD")
    history_lines = history_result.stdout.splitlines() if history_result.returncode == 0 else []
    history_titles = [
        line.split("\t", 2)[2] for line in history_lines if line.count("\t") >= 2
    ]
    for title in M5_LEDGER_TITLES:
        if history_titles.count(title) != 2:
            violations.append(f"ledger:red-green-pair:{title}")

    history_parents = {
        fields[0]: fields[1].split()
        for line in history_lines
        if len(fields := line.split("\t", 2)) == 3
    }
    for red_sha, green_sha in M5_PRIOR_RED_GREEN_COMMITS:
        if red_sha not in history_parents or history_parents.get(green_sha, [None])[0] != red_sha:
            violations.append(f"ledger:prior-pair:{red_sha}:{green_sha}")

    continuation_path = M5_CONTINUATION_REQUIRED_PATHS[0]
    if (ROOT / continuation_path).is_file():
        continuation_lines = read(continuation_path).splitlines()
        for marker in M5_REPLAY_MARKERS:
            if marker not in continuation_lines:
                violations.append(f"continuation:missing-replay-marker:{marker}")
        source_match = re.search(
            r"^Exact WSL source SHA: `([0-9a-f]{40})`$",
            read(continuation_path),
            re.MULTILINE,
        )
        head = git("rev-parse", "HEAD")
        if (
            source_match is None
            or head.returncode != 0
            or source_match.group(1) != head.stdout.strip()
        ):
            violations.append("continuation:source-sha")

    def checksum_manifest_is_valid(path: str) -> bool:
        if not (ROOT / path).is_file():
            return False
        base = (
            ROOT / ".omx/handoff/private-presenter-m5"
            if path.endswith("m5-artifacts.sha256")
            else ROOT
        )
        lines = read(path).splitlines()
        if not lines:
            return False
        for line in lines:
            match = re.fullmatch(r"([0-9a-f]{64})  ([^\r\n]+)", line)
            if match is None:
                return False
            relative = Path(match.group(2))
            if relative.is_absolute() or ".." in relative.parts:
                return False
            target = base / relative
            if not target.is_file():
                return False
            if hashlib.sha256(target.read_bytes()).hexdigest() != match.group(1):
                return False
        return True

    source_manifest_path = M5_CONTINUATION_REQUIRED_PATHS[2]
    if (ROOT / source_manifest_path).is_file():
        source_manifest_lines = read(source_manifest_path).splitlines()
        source_manifest_paths: list[str] = []
        for line in source_manifest_lines:
            match = re.fullmatch(r"[0-9a-f]{64}  ([^\r\n]+)", line)
            if match is not None:
                source_manifest_paths.append(match.group(1))
        if len(source_manifest_paths) != len(set(source_manifest_paths)):
            violations.append("continuation:source-manifest-duplicate")
        expected_result = git(
            "diff",
            "--name-only",
            "--diff-filter=ACMR",
            f"{M5_BASELINE}..HEAD",
        )
        expected_source_paths = (
            sorted(filter(None, expected_result.stdout.splitlines()))
            if expected_result.returncode == 0
            else []
        )
        if source_manifest_paths != expected_source_paths:
            violations.append("continuation:source-manifest-path-set")

    for path in M5_CONTINUATION_REQUIRED_PATHS[1:3]:
        if not checksum_manifest_is_valid(path):
            violations.append(f"continuation:checksum:{path}")

    if joined_app_sources.count("final class AppModel") != 1:
        violations.append("authority:AppModel-count")
    if joined_app_sources.count("@Observable") != 1:
        violations.append("authority:observable-store-count")
    if joined_app_sources.count("TeleprompterPanel(contentRect:") != 1:
        violations.append("authority:panel-construction-count")
    if joined_app_sources.count("EditorTextSystem(") != 1:
        violations.append("authority:editor-construction-count")
    if joined_app_sources.count("ReaderTextSystem(") != 1:
        violations.append("authority:reader-construction-count")
    if joined_app_sources.count("NSStatusBar.system.statusItem(") != 1:
        violations.append("authority:status-item-construction-count")
    if joined_app_sources.count("ScrollSessionController(") != 1:
        violations.append("authority:scroll-session-construction-count")
    product_hot_keys = app_sources.get(
        "PrivatePresenterApp/Services/CarbonHotKeyService.swift", ""
    )
    if product_hot_keys.count("InstallEventHandler(") != 1:
        violations.append("authority:product-handler-install-count")

    app_model = app_sources.get("PrivatePresenterApp/App/AppModel.swift", "")
    if "@MainActor\n@Observable\nfinal class AppModel" not in app_model:
        violations.append("authority:AppModel-main-actor")

    snapshot_path = (
        "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/"
        "PersistedSnapshot.swift"
    )
    document_path = (
        "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/"
        "ScriptDocument.swift"
    )
    if "static let currentSchemaVersion = 1" not in production_sources.get(
        snapshot_path, ""
    ):
        violations.append("schema:persisted-snapshot-version")
    if "static let currentSchemaVersion = 1" not in production_sources.get(
        document_path, ""
    ):
        violations.append("schema:script-document-version")

    protected_dependency_sources = (
        ("project.yml", "dependency:project-yml-changed"),
        (
            "Packages/TeleprompterCore/Package.swift",
            "dependency:package-swift-changed",
        ),
        ("PrivatePresenterApp/Info.plist", "permission:info-plist-changed"),
        (
            "PrivatePresenterApp/Resources/PrivatePresenter.entitlements",
            "entitlement:changed",
        ),
    )
    for path, label in protected_dependency_sources:
        baseline_returncode, baseline_bytes = committed_bytes(M5_BASELINE, path)
        expected = approved_metadata_repair_bytes(path, baseline_bytes).decode("utf-8")
        if baseline_returncode != 0 or not (migrated_source_compatible(path, expected) if phone_migration_active() else expected == read(path)):
            violations.append(label)

    entitlements = read("PrivatePresenterApp/Resources/PrivatePresenter.entitlements")
    if any(
        marker in entitlements
        for marker in (
            "com.apple.security.network.client",
            "com.apple.security.network.server",
            "com.apple.security.automation.apple-events",
            "com.apple.security.device.audio-input",
            "com.apple.security.device.camera",
            "com.apple.security.personal-information",
            "com.apple.developer.icloud",
        )
    ):
        violations.append("entitlement:non-sandbox-surface")

    panel = app_sources.get("PrivatePresenterApp/Overlay/TeleprompterPanel.swift", "")
    runtime = app_sources.get("PrivatePresenterApp/App/AppRuntime.swift", "")
    dependency_container = app_sources.get(
        "PrivatePresenterApp/App/DependencyContainer.swift", ""
    )
    if "proofLevel: OverlayPanelLevel = .statusBar" not in runtime:
        violations.append("panel:status-bar-default")
    if "orderingMode: OverlayPanelOrderingMode = .frontRegardless" not in dependency_container:
        violations.append("panel:front-regardless-default")
    if "override var canBecomeMain: Bool { false }" not in panel:
        violations.append("panel:permanent-non-main")
    if "override var canBecomeKey: Bool { !isOverlayLocked && NSApp.isActive }" not in panel:
        violations.append("panel:dynamic-key-eligibility")

    focus_machine = production_sources.get(
        "Packages/TeleprompterCore/Sources/TeleprompterCore/Focus/"
        "FocusChromeStateMachine.swift",
        "",
    )
    if ".scheduleHide(after: 2, token: token)" not in focus_machine:
        violations.append("focus:two-second-deadline")

    return violations


def validate_m6_path_inventory(*, required_paths: tuple[str, ...]) -> list[str]:
    """Require the final M6 inventory without a mutable milestone-stage bypass."""
    return [
        f"missing-path:{path}" for path in required_paths if not (ROOT / path).is_file()
    ]


def m6_expected_screenshot_rows() -> tuple[str, ...]:
    reference_hashes = [digest for _, digest in M6_REFERENCE_HASHES]
    return tuple(
        "| " + " | ".join(
            (
                state,
                "PENDING",
                "PENDING",
                "PENDING",
                *reference_hashes,
                "PENDING",
            )
        ) + " |"
        for state in M6_SCREENSHOT_STATES
    )


def m6_expected_review_rows() -> tuple[str, ...]:
    return tuple(
        f"| {state} | {reference} | PENDING | PENDING | PENDING | PENDING |"
        for state in M6_SCREENSHOT_STATES
        for reference, _ in M6_REFERENCE_HASHES
    )


def validate_m6_result_text(text: str) -> list[str]:
    """Validate a content-neutral PENDING result without promoting host evidence."""
    violations: list[str] = []
    lines = text.splitlines()
    for marker in M6_RESULT_PENDING_FIELDS:
        if lines.count(marker) != 1:
            violations.append(f"evidence:visual-result-pending:{marker}")
    for row in m6_expected_screenshot_rows():
        if lines.count(row) != 1:
            state = row.split("|", 2)[1].strip()
            violations.append(f"evidence:screenshot-row:{state}")
    for row in m6_expected_review_rows():
        if lines.count(row) != 1:
            cells = [cell.strip() for cell in row.strip("|").split("|")]
            violations.append(f"evidence:review-row:{cells[0]}:{cells[1]}")
    for reference, digest in M6_REFERENCE_HASHES:
        if text.count(digest) != len(M6_SCREENSHOT_STATES):
            violations.append(f"evidence:reference-hash:{reference}")
    acceptance_markers = (
        "Every individual state/reference score must be at least 90/100.",
        "Averages are forbidden and cannot mask any individual score below 90/100.",
        "Reviewer identity and written rationale are required per state/reference pair.",
    )
    for marker in acceptance_markers:
        if lines.count(marker) != 1:
            violations.append(f"evidence:acceptance-rule:{marker}")
    review_rows = [
        [cell.strip() for cell in line.strip("|").split("|")]
        for line in lines
        if line.startswith("| ") and line.count("|") == 7
    ]
    for cells in review_rows:
        if len(cells) == 6 and cells[0] in M6_SCREENSHOT_STATES:
            if cells[2:] != ["PENDING", "PENDING", "PENDING", "PENDING"]:
                violations.append(f"evidence:review-overclaim:{cells[0]}:{cells[1]}")
    for marker in (
        "Status: PASS",
        "Status: GREEN",
        "M6 complete",
        "M6 native automated candidate",
        "M6 visual candidate",
        "M6 physical visual candidate",
        "Swift compilation: PASS",
        "AppKit/TextKit/Core Graphics render: PASS",
        "VoiceOver: PASS",
        "Release Instruments: PASS",
        "Keynote: PASS",
        "Physical presenter result: PASS",
    ):
        if marker in text:
            violations.append(f"evidence:overclaim:{marker}")
    for marker in (
        "SENTINEL_PRIVATE_",
        "document.title",
        "document.text",
        "displayID",
        "CGDirectDisplayID",
        "/Users/",
        "/home/",
        "C:\\Users\\",
        "file://",
    ):
        if marker in text:
            violations.append(f"evidence:private-surface:{marker}")
    return violations


def m6_history_rows() -> list[tuple[str, list[str], str]]:
    result = git(
        "log", "--reverse", "--format=%H%x09%P%x09%s",
        f"{M6_PLAN_COMMIT}..{M6_FINAL_SOURCE_COMMIT}"
    )
    if result.returncode != 0:
        return []
    rows: list[tuple[str, list[str], str]] = []
    for line in result.stdout.splitlines():
        fields = line.split("\t", 2)
        if len(fields) == 3:
            rows.append((fields[0], fields[1].split(), fields[2]))
    return rows


def validate_m6_history_rows(
    rows: list[tuple[str, list[str], str]],
) -> list[str]:
    violations: list[str] = []
    expected_titles = [title for title in M6_LEDGER_TITLES for _ in range(2)]
    if len(rows) != len(expected_titles):
        violations.append("ledger:exact-history-count")
        return violations
    if [title for _, _, title in rows] != expected_titles:
        violations.append("ledger:exact-history-titles")
    previous = M6_PLAN_COMMIT
    for index, (commit, parents, _) in enumerate(rows):
        if parents != [previous]:
            violations.append(f"ledger:nonconsecutive:{index}")
        previous = commit
    for index, pair in enumerate(M6_PRIOR_LEDGER_PAIRS):
        actual = (rows[index * 2][0], rows[index * 2 + 1][0])
        if actual != pair:
            violations.append(f"ledger:prior-pair:{index}")
    return violations


def validate_m6_lore_message(message: str) -> list[str]:
    violations: list[str] = []
    if r"\n" in message:
        violations.append("literal-newline")
    lines = message.rstrip("\n").splitlines()
    trailer_pattern = re.compile(
        rf"^({'|'.join(re.escape(key) for key in M6_LORE_TRAILER_KEYS)}): .+$"
    )
    intended = [line for line in lines if trailer_pattern.fullmatch(line)]
    if not intended:
        violations.append("missing-trailers")
        return violations
    parsed = subprocess.run(
        ["git", "interpret-trailers", "--parse"],
        cwd=ROOT,
        input=message,
        text=True,
        capture_output=True,
        check=False,
    )
    if parsed.returncode != 0 or parsed.stdout.rstrip("\n").splitlines() != intended:
        violations.append("unparsed-trailers")
    first = next(index for index, line in enumerate(lines) if trailer_pattern.fullmatch(line))
    if lines[first:] != intended:
        violations.append("noncontiguous-trailers")
    return violations


def validate_m6_lore_history(
    rows: list[tuple[str, list[str], str]],
) -> list[str]:
    violations: list[str] = []
    for commit, _, _ in rows:
        result = git("show", "-s", "--format=%B", commit)
        if result.returncode != 0:
            violations.append(f"ledger:lore-message:{commit}")
            continue
        for problem in validate_m6_lore_message(result.stdout):
            violations.append(f"ledger:lore-{problem}:{commit}")
    return violations


def parse_sha256_manifest(path: Path) -> tuple[list[tuple[str, str]], list[str]]:
    if not path.is_file():
        return [], [f"continuation:missing-manifest:{path.name}"]
    entries: list[tuple[str, str]] = []
    violations: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([^\r\n]+)", line)
        if match is None:
            violations.append(f"continuation:manifest-format:{path.name}")
            continue
        digest, relative = match.groups()
        relative_path = Path(relative)
        if relative_path.is_absolute() or ".." in relative_path.parts:
            violations.append(f"continuation:manifest-path:{path.name}:{relative}")
            continue
        entries.append((digest, relative))
    if len(entries) != len({relative for _, relative in entries}):
        violations.append(f"continuation:manifest-duplicate:{path.name}")
    return entries, violations


def validate_m6_continuation_guide(
    text: str,
    *,
    history_rows: list[tuple[str, list[str], str]],
    source_sha: str,
    source_tree: str,
) -> list[str]:
    violations: list[str] = []
    lines = text.splitlines()
    identities = (
        f"Exact M6 plan SHA: `{M6_PLAN_COMMIT}`",
        f"Exact WSL source SHA: `{source_sha}`",
        f"Exact Git tree: `{source_tree}`",
        f"Immutable M5 manifest SHA-256 prerequisite: `{M6_M5_HANDOFF_MANIFEST_SHA256}`",
    )
    for marker in identities:
        if lines.count(marker) != 1:
            violations.append(f"continuation:identity:{marker.split(':', 1)[0]}")
    required_markers = (
        "Status: PENDING controlled-Mac replay; M6 WSL source candidate only",
        "M3 native evidence: PENDING",
        "M4 native evidence: PENDING",
        "M5 native evidence: PENDING",
        "M6 Swift/AppKit/TextKit/Core Graphics compilation and render: PENDING",
        "M6 screenshot capture and reference scores: PENDING",
        "M6 accessibility and VoiceOver: PENDING",
        "M6 Release performance and Instruments: PENDING",
        "M6 Keynote/private-display/audience-display/physical proof: PENDING",
        "Replay every RED SHA before its immediate GREEN child.",
        "A configuration, missing SDK, missing display, or missing Keynote is not a valid RED.",
        "Maximum honest label: M6 WSL source candidate; M3-M5 native evidence pending",
        "Stop before M7; do not edit HANDOFF.md or push.",
        "./Scripts/bootstrap-macos.sh",
        "xcodebuild analyze -project PrivatePresenter.xcodeproj",
        "xcodebuild build -project PrivatePresenter.xcodeproj",
        "xcrun swift-format lint --recursive Packages PrivatePresenterApp",
        "M6 render test: PENDING",
        "Five controlled synthetic screenshots: PENDING",
        "Keyboard/VoiceOver/Accessibility Inspector audit: PENDING",
        "M5 50,000-word Release replay and Instruments: PENDING",
        "Keynote extended nonmirrored private/audience display gate: PENDING",
    )
    for marker in required_markers:
        if text.count(marker) != 1:
            violations.append(f"continuation:missing-marker:{marker}")
    expected_pairs = [
        (rows[0][0], rows[1][0])
        for rows in (history_rows[index:index + 2] for index in range(0, len(history_rows), 2))
        if len(rows) == 2
    ]
    pair_pattern = re.compile(
        r"^\| M6\.(\d+) \| `([0-9a-f]{40})` \| `([0-9a-f]{40})` \| "
        r"`python3 -B Scripts/test_validate_project_structure_m6\.py` \| ([^|]+) \|$",
        re.MULTILINE,
    )
    pair_matches = pair_pattern.findall(text)
    if len(pair_matches) != len(M6_LEDGER_TITLES):
        violations.append("continuation:pair-count")
    else:
        labels = [int(label) for label, _, _, _ in pair_matches]
        pairs = [(red, green) for _, red, green, _ in pair_matches]
        expectations = [expectation.strip() for _, _, _, expectation in pair_matches]
        if labels != list(range(len(M6_LEDGER_TITLES))):
            violations.append("continuation:pair-labels")
        if pairs != expected_pairs:
            violations.append("continuation:pairs")
        if any(not expectation.startswith("Expected RED:") for expectation in expectations):
            violations.append("continuation:pair-expectations")
    for marker in M6_STAGE_RECONSTRUCTION_MARKERS:
        if marker not in text:
            violations.append(f"continuation:stage-reconstruction-marker:{marker}")
    replay_pattern = re.compile(
        r"^(\d+) ([0-9a-f]{40}) ([0-9a-f]{40}) (native|static)$",
        re.MULTILINE,
    )
    replay_rows = replay_pattern.findall(text)
    replay_pairs = [(red, green) for _, red, green, _ in replay_rows]
    if [int(label) for label, _, _, _ in replay_rows] != list(
        range(len(M6_LEDGER_TITLES))
    ) or replay_pairs != expected_pairs:
        violations.append("continuation:explicit-replay-pairs")
    native_labels = tuple(
        int(label) for label, _, _, replay_kind in replay_rows
        if replay_kind == "native"
    )
    if native_labels != M6_NATIVE_REPLAY_PAIR_LABELS:
        violations.append("continuation:native-replay-pairs")
    for marker in (
        "Status: PASS",
        "M6 complete",
        "M6 native automated candidate",
        "M6 visual candidate",
        "M6 physical visual candidate",
        "VoiceOver: PASS",
        "Instruments: PASS",
        "Keynote: PASS",
    ):
        if marker in text:
            violations.append(f"continuation:overclaim:{marker}")
    for marker in (
        "SENTINEL_PRIVATE_",
        "document.title",
        "document.text",
        "displayID",
        "CGDirectDisplayID",
        "/Users/",
        "/home/",
        "C:\\Users\\",
        "file://",
    ):
        if marker in text:
            violations.append(f"continuation:private-surface:{marker}")
    return violations


def validate_m6_continuation(handoff_root: Path | None = None) -> list[str]:
    handoff = handoff_root or ROOT / M6_CONTINUATION_DIR
    violations: list[str] = []
    actual_files = (
        tuple(sorted(path.name for path in handoff.iterdir() if path.is_file()))
        if handoff.is_dir()
        else ()
    )
    if actual_files != tuple(sorted(M6_CONTINUATION_FILES)):
        violations.append("continuation:exact-file-inventory")
    head = git("rev-parse", M6_FINAL_SOURCE_COMMIT)
    tree = git("rev-parse", f"{M6_FINAL_SOURCE_COMMIT}^{{tree}}")
    if head.returncode != 0 or tree.returncode != 0:
        return [*violations, "continuation:git-identity"]
    source_sha = head.stdout.strip()
    source_tree = tree.stdout.strip()
    guide = handoff / "MAC-CONTINUATION.md"
    if guide.is_file():
        violations.extend(
            validate_m6_continuation_guide(
                guide.read_text(encoding="utf-8"),
                history_rows=m6_history_rows(),
                source_sha=source_sha,
                source_tree=source_tree,
            )
        )
    else:
        violations.append("continuation:missing-guide")

    source_manifest = handoff / "m6-source-files.sha256"
    source_entries, source_manifest_violations = parse_sha256_manifest(source_manifest)
    violations.extend(source_manifest_violations)
    expected_paths_result = git(
        "diff", "--name-only", "--diff-filter=ACMR", f"{M6_PLAN_COMMIT}..{source_sha}"
    )
    expected_paths = (
        sorted(filter(None, expected_paths_result.stdout.splitlines()))
        if expected_paths_result.returncode == 0
        else []
    )
    source_paths = [relative for _, relative in source_entries]
    if source_paths != expected_paths:
        violations.append("continuation:source-manifest-paths")
    for digest, relative in source_entries:
        returncode, source_bytes = committed_bytes(source_sha, relative)
        if returncode != 0 or hashlib.sha256(source_bytes).hexdigest() != digest:
            violations.append(f"continuation:source-hash:{relative}")

    artifact_manifest = handoff / "m6-artifacts.sha256"
    artifact_entries, artifact_manifest_violations = parse_sha256_manifest(
        artifact_manifest
    )
    violations.extend(artifact_manifest_violations)
    artifact_paths = [relative for _, relative in artifact_entries]
    if artifact_paths != list(M6_ARTIFACT_MANIFEST_ENTRIES):
        violations.append("continuation:artifact-manifest-paths")
    for digest, relative in artifact_entries:
        target = handoff / relative
        if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            violations.append(f"continuation:artifact-hash:{relative}")

    archive = handoff / "private-presenter-m6-source.tar"
    if archive.is_file():
        try:
            with tarfile.open(archive, mode="r:") as source_tar:
                members = source_tar.getmembers()
                member_names = [member.name for member in members]
                if member_names != expected_paths or len(member_names) != len(set(member_names)):
                    violations.append("continuation:tar-paths")
                for member in members:
                    extracted = source_tar.extractfile(member)
                    returncode, source_bytes = committed_bytes(
                        source_sha, member.name
                    )
                    if (
                        not member.isfile()
                        or member.mtime != 0
                        or member.uid != 0
                        or member.gid != 0
                        or extracted is None
                        or returncode != 0
                        or extracted.read() != source_bytes
                    ):
                        violations.append(f"continuation:tar-entry:{member.name}")
        except (tarfile.TarError, OSError):
            violations.append("continuation:tar-invalid")
    else:
        violations.append("continuation:tar-missing")

    bundle = handoff / "private-presenter-m6-wsl.bundle"
    if bundle.is_file():
        verify = subprocess.run(
            ["git", "bundle", "verify", bundle.name],
            cwd=handoff,
            check=False,
            text=True,
            capture_output=True,
        )
        heads = subprocess.run(
            ["git", "bundle", "list-heads", bundle.name],
            cwd=handoff,
            check=False,
            text=True,
            capture_output=True,
        )
        if verify.returncode != 0:
            violations.append("continuation:bundle-verify")
        expected_head = f"{source_sha} HEAD"
        if heads.returncode != 0 or heads.stdout.splitlines() != [expected_head]:
            violations.append("continuation:bundle-head")
    else:
        violations.append("continuation:bundle-missing")
    return violations


def validate_m6_source() -> list[str]:
    """Validate the final M6 WSL source candidate and host-bound continuation."""
    violations = validate_m6_path_inventory(
        required_paths=(
            "Scripts/test_validate_project_structure_m6.py",
            *M6_M1_REQUIRED_PATHS,
            *M6_M3_REQUIRED_PATHS,
            *M6_M5_VISUAL_REQUIRED_PATHS,
            *M6_FINAL_EVIDENCE_PATHS,
        ),
    )

    parent = git("rev-parse", f"{M6_PLAN_COMMIT}^")
    if parent.returncode != 0 or parent.stdout.strip() != M6_PLAN_PARENT:
        violations.append("ancestry:m6-plan-parent")
    plan_paths = git(
        "diff-tree", "--no-commit-id", "--name-only", "-r", M6_PLAN_COMMIT
    )
    if plan_paths.returncode != 0 or plan_paths.stdout.splitlines() != [M6_PLAN_PATH]:
        violations.append("ancestry:m6-plan-path")
    if git(
        "merge-base", "--is-ancestor", M6_FINAL_SOURCE_COMMIT, "HEAD"
    ).returncode != 0:
        violations.append("ancestry:m6-plan-not-ancestor")

    for path in M6_PROTECTED_PATHS:
        baseline_returncode, baseline_bytes = committed_bytes(M6_PLAN_COMMIT, path)
        current = (ROOT / path).read_bytes() if (ROOT / path).is_file() else None
        if baseline_returncode != 0 or current != baseline_bytes:
            violations.append(f"protected-byte:{path}")

    for path in M6_IMMUTABLE_SOURCE_PATHS:
        baseline_returncode, baseline_bytes = committed_bytes(M6_PLAN_COMMIT, path)
        current = (ROOT / path).read_bytes() if (ROOT / path).is_file() else None
        expected_bytes = baseline_bytes
        if path in M6_APPROVED_METADATA_TYPE_REPAIRS:
            old, new = M6_APPROVED_METADATA_TYPE_REPAIRS[path]
            if baseline_bytes.count(old) != 1:
                violations.append(f"immutable:metadata-baseline:{path}")
                continue
            expected_bytes = approved_metadata_repair_bytes(path, baseline_bytes)
        if phone_migration_active() and path in ("project.yml", "Packages/TeleprompterCore/Package.swift"):
            if baseline_returncode != 0 or not migrated_source_compatible(path, expected_bytes.decode("utf-8")):
                violations.append(f"immutable:source-creep:{path}")
        elif phone_migration_active() and path in PORTABLE_MOVES:
            moved = ROOT / PORTABLE_MOVES[path]
            alias = b"import PromptingCore\n\npublic typealias ScriptDocument = PromptingCore.ScriptDocument\n"
            if not moved.is_file() or moved.read_bytes() != expected_bytes or current != alias:
                violations.append(f"immutable:source-creep:{path}")
        elif baseline_returncode != 0 or current != expected_bytes:
            violations.append(f"immutable:source-creep:{path}")

    for label, path, marker in M6_PREDECESSOR_PENDING_CLAIMS:
        if not (ROOT / path).is_file() or read(path).splitlines().count(marker) != 1:
            violations.append(f"evidence:predecessor-pending:{label}")

    committed_changes = git(
        "diff", "--name-only", "--diff-filter=ACMR",
        f"{M6_PLAN_COMMIT}..{M6_FINAL_SOURCE_COMMIT}"
    )
    if committed_changes.returncode != 0:
        violations.append("scope:m6-final-history")
    else:
        changed_paths = tuple(sorted(filter(None, committed_changes.stdout.splitlines())))
        if changed_paths != tuple(sorted(M6_FINAL_CHANGED_PATHS)):
            violations.append("scope:m6-final-exact-paths")

    if (ROOT / M6_RESULT_PATH).is_file():
        violations.extend(validate_m6_result_text(read(M6_RESULT_PATH)))
    else:
        violations.append("evidence:visual-result-missing")
    history_rows = m6_history_rows()
    violations.extend(validate_m6_history_rows(history_rows))
    violations.extend(validate_m6_lore_history(history_rows))
    violations.extend(validate_m6_continuation())

    production_paths = [
        path.relative_to(ROOT).as_posix()
        for root in (ROOT / "Packages/TeleprompterCore/Sources", ROOT / "PrivatePresenterApp")
        for path in root.rglob("*.swift")
    ]
    production_sources = {path: read(path) for path in production_paths}
    if phone_migration_active():
        for old, new in PORTABLE_MOVES.items():
            if new in production_sources:
                production_sources[old] = production_sources[new]
    joined_sources = "\n".join(production_sources.values())

    visual_tests_path = "PrivatePresenterAppTests/OverlayVisualSnapshotTests.swift"
    visual_tests = read(visual_tests_path) if (ROOT / visual_tests_path).is_file() else ""
    for milestone, names in (
        ("m1", M6_M1_NAMED_TESTS),
        ("m2", M6_M2_NAMED_TESTS),
        ("m3", M6_M3_NAMED_TESTS),
        ("m4", M6_M4_NAMED_TESTS),
        ("m5", M6_M5_VISUAL_NAMED_TESTS),
        ("repair", M6_REPAIR_NAMED_TESTS),
        ("band-repair", M6_BAND_REPAIR_NAMED_TESTS),
        ("oracle-repair", M6_ORACLE_REPAIR_NAMED_TESTS),
        ("hosted-evidence-repair", M6_HOSTED_EVIDENCE_REPAIR_NAMED_TESTS),
    ):
        for name in names:
            if visual_tests.count(f"func {name}()") != 1:
                violations.append(f"visual:{milestone}-missing-test:{name}")
    for label, path, marker in M6_M1_SOURCE_MARKERS:
        if not (ROOT / path).is_file() or read(path).count(marker) != 1:
            violations.append(f"visual:m1-missing-marker:{label}")
    for label, path, marker, expected_count in M6_M2_SOURCE_MARKERS:
        if not (ROOT / path).is_file() or read(path).count(marker) != expected_count:
            violations.append(f"visual:m2-missing-marker:{label}")
    for label, path, marker, expected_count in M6_M3_SOURCE_MARKERS:
        if not (ROOT / path).is_file() or read(path).count(marker) != expected_count:
            violations.append(f"visual:m3-missing-marker:{label}")
    for label, path, marker, expected_count in M6_M4_SOURCE_MARKERS:
        if not (ROOT / path).is_file() or read(path).count(marker) != expected_count:
            violations.append(f"visual:m4-missing-marker:{label}")
    m5_support_path = M6_M5_VISUAL_REQUIRED_PATHS[0]
    m5_support = read(m5_support_path) if (ROOT / m5_support_path).is_file() else ""
    for label, marker, expected_count in M6_M5_VISUAL_SOURCE_MARKERS:
        if m5_support.count(marker) != expected_count:
            violations.append(f"visual:m5-missing-marker:{label}")
    for label, path, marker, expected_count in M6_REPAIR_SOURCE_MARKERS:
        if not (ROOT / path).is_file() or read(path).count(marker) != expected_count:
            violations.append(f"visual:repair-missing-marker:{label}")
    for label, path, marker in M6_REPAIR_FORBIDDEN_MARKERS:
        if (ROOT / path).is_file() and marker in read(path):
            violations.append(f"visual:repair-forbidden:{label}")

    for label, path, marker, expected_count in M6_BAND_REPAIR_SOURCE_MARKERS:
        if not (ROOT / path).is_file() or read(path).count(marker) != expected_count:
            violations.append(f"visual:band-repair-missing-marker:{label}")

    for label, marker, expected_count in M6_ORACLE_REPAIR_SOURCE_MARKERS:
        if m5_support.count(marker) != expected_count:
            violations.append(f"visual:oracle-repair-missing-marker:{label}")
    for label, marker in M6_ORACLE_REPAIR_FORBIDDEN_MARKERS:
        if marker in m5_support:
            violations.append(f"visual:oracle-repair-forbidden:{label}")
    for label, marker, expected_count in M6_HOSTED_EVIDENCE_REPAIR_SOURCE_MARKERS:
        if m5_support.count(marker) != expected_count:
            violations.append(f"visual:hosted-evidence-repair-missing-marker:{label}")
    for label, marker in M6_HOSTED_EVIDENCE_REPAIR_FORBIDDEN_MARKERS:
        if marker in m5_support:
            violations.append(f"visual:hosted-evidence-repair-forbidden:{label}")
    mask_source = m5_support.split(
        "private static func makeLiteralCardMask", 1
    )[-1].split("private static func drawLiteralSurface", 1)[0]
    if any(
        marker in mask_source
        for marker in ("CGPath(roundedRect:", "addArc(", "addCurve(")
    ):
        violations.append("visual:oracle-repair-hand-coded-mask")

    adapter_source = production_sources.get(
        "PrivatePresenterApp/Overlay/ReaderViewportAdapter.swift", ""
    )
    selection_source = adapter_source.split(
        "static func selectActiveBandLineFragments", 1
    )[-1].split("func captureAnchor", 1)[0]
    if ".sorted" in selection_source:
        violations.append("visual:band-repair-selection-resort")
    clip_source = adapter_source.split("func setClipOriginY", 1)[-1].split(
        "func invalidateActiveBandLineMetrics", 1
    )[0]
    if any(marker in clip_source for marker in ("ensureLayout(", "model", ".send(")):
        violations.append("visual:band-repair-clip-owner-creep")
    container_source = production_sources.get(
        "PrivatePresenterApp/Overlay/ReaderTextView.swift", ""
    )
    cache_refresh_source = container_source.split(
        "func refreshActiveBandLayoutFromCachedMetrics", 1
    )[-1].split("static func resolvedActiveBandHeight", 1)[0]
    if any(marker in cache_refresh_source for marker in ("ensureLayout(", "NSTextLayoutManager(")):
        violations.append("visual:band-repair-cache-owner-creep")

    oracle_support = m5_support.split("static func makeCanonicalSemanticOracle", 1)[-1]
    for marker in (
        "OverlayVisualTokens",
        "OverlayLayoutMetrics",
    ):
        if marker in oracle_support:
            violations.append(f"visual:m5-forbidden:{marker}")

    for marker in (
        "WKWebView",
        "HTML",
        "CGWindowListCreateImage",
        "SCScreenshotManager",
        "recordBaseline",
        "golden",
    ):
        if marker in m5_support:
            violations.append(f"visual:m5-forbidden:{marker}")

    resolver_source = read("PrivatePresenterApp/Overlay/OverlayRootView.swift")
    precedence_markers = (
        "for region in metrics.controlRegions",
        "for region in metrics.cornerResizeRegions",
        "for region in metrics.edgeResizeRegions",
        "if Self.contains(point, in: metrics.titleDragFrame)",
    )
    precedence_positions = [resolver_source.find(marker) for marker in precedence_markers]
    if any(position < 0 for position in precedence_positions) or precedence_positions != sorted(
        precedence_positions
    ):
        violations.append("visual:m4-hit-precedence")
    if ".aspectRatio(" in resolver_source or ".fixedSize(" in resolver_source:
        violations.append("visual:m4-aspect-lock")

    root_source = production_sources.get(
        "PrivatePresenterApp/Overlay/OverlayRootView.swift", ""
    )
    chrome_source = read("PrivatePresenterApp/Overlay/OverlayChromeView.swift")
    if "privatePresenter.overlayVisibility" in chrome_source:
        violations.append("visual:m3-old-visibility-control")
    if "if isChromeVisible" in root_source:
        violations.append("visual:m3-conditional-chrome")

    reader_source = production_sources.get(
        "PrivatePresenterApp/Overlay/ReaderTextView.swift", ""
    )
    panel_source = production_sources.get(
        "PrivatePresenterApp/Overlay/TeleprompterPanel.swift", ""
    )
    for label, source, marker in (
        ("old-root-fill", root_source, "Color(red: 0.05, green: 0.06, blue: 0.09)"),
        ("old-reader-fill", reader_source, "red: 0.05,\n            green: 0.06"),
        ("card-glow", root_source, ".shadow("),
    ):
        if marker in source:
            violations.append(f"visual:m1-forbidden:{label}")
    if "hasShadow = true" not in panel_source:
        violations.append("visual:m1-panel-shadow")
    if "isOpaque = false" not in panel_source:
        violations.append("visual:m1-window-curved-alpha")

    prohibited = (
        "addGlobalMonitorForEvents",
        "addLocalMonitorForEvents",
        "CGEventTap",
        "CGEvent.tapCreate",
        "AXIsProcessTrusted",
        "AXUIElement",
        "NSApp.activate(",
        "makeKeyAndOrderFront(",
        "URLSession",
        "URLRequest",
        "NSURLConnection",
        "NWConnection",
        "import Network",
        "WKWebView",
        "CGWindowListCreateImage",
        "SCScreenshotManager",
        "MetricKit",
        "Sentry",
        "telemetry",
        "analytics",
    )
    for path, source in production_sources.items():
        for marker in prohibited:
            if marker in source:
                violations.append(f"prohibited:{marker}:{path}")

    authority_counts = (
        ("AppModel-count", "final class AppModel", 1),
        ("observable-store-count", "@Observable", 1),
        ("panel-construction-count", "TeleprompterPanel(contentRect:", 1),
        ("reader-construction-count", "ReaderTextSystem(", 1),
        ("scroll-session-construction-count", "ScrollSessionController(", 1),
        ("focus-state-machine-count", "FocusChromeStateMachine()", 1),
    )
    for label, marker, expected_count in authority_counts:
        if joined_sources.count(marker) != expected_count:
            violations.append(f"authority:{label}")
    app_model = production_sources.get("PrivatePresenterApp/App/AppModel.swift", "")
    if "@MainActor\n@Observable\nfinal class AppModel" not in app_model:
        violations.append("authority:AppModel-main-actor")
    panel = production_sources.get(
        "PrivatePresenterApp/Overlay/TeleprompterPanel.swift", ""
    )
    for label, marker in (
        ("nonactivating", ".nonactivatingPanel"),
        ("permanent-non-main", "override var canBecomeMain: Bool { false }"),
        (
            "dynamic-key-eligibility",
            "override var canBecomeKey: Bool { !isOverlayLocked && NSApp.isActive }",
        ),
    ):
        if marker not in panel:
            violations.append(f"panel:{label}")

    snapshot = production_sources.get(
        "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/"
        "PersistedSnapshot.swift",
        "",
    )
    document = production_sources.get(
        "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ScriptDocument.swift",
        "",
    )
    if "currentSchemaVersion = 1" not in snapshot:
        violations.append("schema:persisted-snapshot-version")
    if "currentSchemaVersion = 1" not in document:
        violations.append("schema:script-document-version")

    runner = read("Scripts/verify-wsl.sh")
    runner_markers = (
        'M5_HANDOFF="$PWD/.omx/handoff/private-presenter-m5"',
        f"M5_MANIFEST_SHA={M6_M5_HANDOFF_MANIFEST_SHA256}",
        'find "$M5_HANDOFF" -maxdepth 1 -type f',
        'sha256sum "$M5_HANDOFF/m5-artifacts.sha256"',
        f'git worktree add --detach "$M5_ROOT/tree" {M6_PLAN_PARENT}',
        M6_M5_SOURCE_TREE,
        'cp -a "$M5_HANDOFF" "$M5_ROOT/tree/.omx/handoff/private-presenter-m5"',
        "trap 'git worktree remove --force",
        "python3 -B Scripts/test_validate_project_structure_m5.py",
        "python3 -B Scripts/test_validate_project_structure_m6.py",
    )
    for marker in runner_markers:
        if marker not in runner:
            violations.append(f"runner:missing-marker:{marker}")
    for marker, expected_count in (
        ("sha256sum -c m5-artifacts.sha256", 2),
        ("git bundle verify private-presenter-m5-wsl.bundle", 2),
        ("python3 Scripts/validate_project_structure.py", 2),
        ("python3 -B Scripts/test_validate_project_structure_m5.py", 1),
        ("python3 -B Scripts/test_validate_project_structure_m6.py", 1),
    ):
        if runner.count(marker) != expected_count:
            violations.append(f"runner:marker-count:{marker}")
    inventory_start = runner.find('M5_EXPECTED_FILES="$(printf')
    inventory_end = runner.find('test "$(find', inventory_start)
    inventory_source = runner[inventory_start:inventory_end]
    if inventory_start < 0 or inventory_end <= inventory_start:
        violations.append("runner:m5-inventory-block")
    else:
        for name in M6_M5_HANDOFF_FILES:
            if inventory_source.count(name) != 1:
                violations.append(f"runner:m5-inventory:{name}")

    epoch_start = runner.find('(cd "$M5_ROOT/tree"')
    epoch_end = runner.find('git worktree remove --force "$M5_ROOT/tree"', epoch_start)
    m5_position = runner.find("python3 -B Scripts/test_validate_project_structure_m5.py")
    m6_position = runner.find("python3 -B Scripts/test_validate_project_structure_m6.py")
    if not (
        epoch_start >= 0
        and epoch_end > epoch_start
        and epoch_start < m5_position < epoch_end < m6_position
    ):
        violations.append("runner:epoch-routing")

    validator_source = read("Scripts/validate_project_structure.py")
    main_start = validator_source.rfind("def " + "main() -> None:")
    main_source = validator_source[main_start:]
    if main_source.count("validate_" + "m6_source()") != 1:
        violations.append("runner:current-m6-main-count")
    if "validate_" + "m5_source()" in main_source:
        violations.append("runner:current-m5-main")

    return violations



def main() -> None:
    missing = [path for path in REQUIRED_PATHS if not (ROOT / path).is_file()]
    if missing:
        fail("missing required paths: " + ", ".join(missing))
    if read(".xcodegen-version").strip() != "2.45.4":
        fail(".xcodegen-version must contain exactly 2.45.4")
    if "ENABLE_DEBUG_DYLIB = NO" not in read("Config/Debug.xcconfig"):
        fail("Debug proof builds must disable unbound debug-dylib indirection")
    project = read("project.yml")
    absent_markers = [marker for marker in PROJECT_MARKERS if marker not in project]
    if absent_markers:
        fail("project.yml is missing markers: " + ", ".join(absent_markers))
    if "/PrivatePresenter.xcodeproj/" not in read(".gitignore"):
        fail("generated PrivatePresenter.xcodeproj must be ignored")
    ignored = git("check-ignore", "-q", "PrivatePresenter.xcodeproj/project.pbxproj")
    if ignored.returncode != 0:
        fail("generated project path is not ignored by Git")
    tracked = git("ls-files", "PrivatePresenter.xcodeproj")
    if tracked.stdout.strip():
        fail("generated project files must not be tracked")
    validate_plists()
    swift_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for root in (ROOT / "Packages", ROOT / "PrivatePresenterAppTests")
        for path in root.rglob("*.swift")
    )
    missing_tests = [name for name in NAMED_TESTS if name not in swift_sources]
    if missing_tests:
        fail("missing required named tests: " + ", ".join(missing_tests))
    phase_a_inventory = swift_sources + "\n" + read(
        "Scripts/test-verify-m0-proof-provenance.sh"
    )
    missing_phase_a_tests = [
        name
        for name in (*PHASE_A_NAMED_TESTS, *PROVENANCE_FIXTURE_TESTS)
        if name not in phase_a_inventory
    ]
    if missing_phase_a_tests:
        fail("missing required Phase A named tests: " + ", ".join(missing_phase_a_tests))
    missing_phase_b_tests = [
        name for name in PHASE_B_NAMED_TESTS if name not in phase_a_inventory
    ]
    if missing_phase_b_tests:
        fail("missing required Phase B named tests: " + ", ".join(missing_phase_b_tests))
    if phone_migration_active():
        phone_violations = validate_phone_boundary(ROOT, read)
        if phone_violations:
            fail("iPhone dependency validation failed: " + ", ".join(phone_violations))
    else:
        core_imports = [
            line.strip()
            for path in (ROOT / "Packages/TeleprompterCore/Sources").rglob("*.swift")
            for line in path.read_text(encoding="utf-8").splitlines()
            if line.strip().startswith("import ") and line.strip() != "import Foundation"
        ]
        if core_imports:
            fail("TeleprompterCore must import Foundation only: " + ", ".join(sorted(set(core_imports))))
    app_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (ROOT / "PrivatePresenterApp").rglob("*.swift")
    )
    missing_app_markers = [marker for marker in APP_SOURCE_MARKERS if marker not in app_sources]
    if missing_app_markers:
        fail("M0 proof harness is missing markers: " + ", ".join(missing_app_markers))
    validate_data_safety()
    validate_historical_result_prefix()
    validate_m0_prohibited_surfaces()
    m4_violations = validate_m4_source()
    if m4_violations:
        fail("Milestone 4 source validation failed: " + ", ".join(m4_violations))
    m6_violations = validate_m6_source()
    if m6_violations:
        fail("Milestone 6 validation failed: " + ", ".join(m6_violations))
    validate_xcode_listing()
    print(
        "Project structure validation passed "
        "(Milestone 0 Phase B + Milestone 4 + Milestone 6 source)."
    )


if __name__ == "__main__":
    main()
