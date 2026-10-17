#!/usr/bin/env python3
"""RED/GREEN contract for the Milestone 4 current-source validator."""
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

CANONICAL_NAMES = (
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

FORBIDDEN = (
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


class Milestone4ValidatorContractTests(unittest.TestCase):
    def violations_with(self, replacements: dict[str, str]) -> list[str]:
        original_read = VALIDATOR.read

        def replaced_read(path: str) -> str:
            return replacements[path] if path in replacements else original_read(path)

        with patch.object(VALIDATOR, "read", side_effect=replaced_read):
            return VALIDATOR.validate_m4_source()

    def test_m4_required_path_inventory_is_exact(self) -> None:
        self.assertEqual(tuple(VALIDATOR.M4_REQUIRED_PATHS), EXPECTED_PATHS)

    def test_all_twenty_one_canonical_names_are_enforced_exactly(self) -> None:
        self.assertEqual(tuple(VALIDATOR.M4_CANONICAL_NAMED_TESTS), CANONICAL_NAMES)
        self.assertEqual(len(set(VALIDATOR.M4_CANONICAL_NAMED_TESTS)), 21)

    def test_current_m4_source_satisfies_the_current_validator(self) -> None:
        self.assertEqual(VALIDATOR.validate_m4_source(), [])

    def test_validator_rejects_every_forbidden_permission_monitor_and_scope_surface(self) -> None:
        path = "PrivatePresenterApp/App/AppModel.swift"
        for marker in FORBIDDEN:
            violations = self.violations_with({path: VALIDATOR.read(path) + f"\n// {marker}\n"})
            self.assertTrue(
                any(item.startswith(f"prohibited:{marker}:") for item in violations),
                marker,
            )

    def test_validator_requires_one_model_panel_status_product_handler_and_scroll_owner(self) -> None:
        mutations = (
            ("PrivatePresenterApp/App/AppModel.swift", "\nfinal class AppModel {}\n", "authority:AppModel-count"),
            ("PrivatePresenterApp/Overlay/OverlayPanelController.swift", "\n// TeleprompterPanel(contentRect:\n", "authority:panel-construction-count"),
            ("PrivatePresenterApp/Menu/StatusItemController.swift", "\n// NSStatusBar.system.statusItem(\n", "authority:status-item-construction-count"),
            ("PrivatePresenterApp/Services/CarbonHotKeyService.swift", "\n// InstallEventHandler(\n", "authority:product-handler-install-count"),
            ("PrivatePresenterApp/App/DependencyContainer.swift", "\n// ScrollSessionController(\n", "authority:scroll-session-construction-count"),
        )
        for path, suffix, expected in mutations:
            self.assertIn(expected, self.violations_with({path: VALIDATOR.read(path) + suffix}))

    def test_validator_requires_stable_ids_dynamic_key_and_timing_constants(self) -> None:
        mutations = (
            (
                "PrivatePresenterApp/Overlay/TeleprompterPanel.swift",
                "override var canBecomeKey: Bool { !isOverlayLocked && NSApp.isActive }",
                "override var canBecomeKey: Bool { true }",
                "panel:dynamic-key-eligibility",
            ),
            (
                "Packages/TeleprompterCore/Sources/TeleprompterCore/Focus/FocusChromeStateMachine.swift",
                ".scheduleHide(after: 2, token: token)",
                ".scheduleHide(after: 3, token: token)",
                "focus:two-second-deadline",
            ),
            (
                "PrivatePresenterApp/Overlay/PointerPresenceMonitor.swift",
                "samplingInterval: TimeInterval = 0.1",
                "samplingInterval: TimeInterval = 1",
                "focus:pointer-sampling-interval",
            ),
        )
        for path, old, new, expected in mutations:
            self.assertIn(expected, self.violations_with({path: VALIDATOR.read(path).replace(old, new)}))

        identifiers = VALIDATOR.read("PrivatePresenterApp/Interfaces/HotKeyRegistering.swift")
        self.assertIn("action.stableIndex + 1", identifiers)

    def test_validator_requires_exact_five_typed_privacy_safe_menu_actions(self) -> None:
        path = "PrivatePresenterApp/Menu/StatusItemController.swift"
        source = VALIDATOR.read(path)
        self.assertIn("menu:exact-five-actions", self.violations_with({path: source + '\n// NSMenuItem(title:\n'}))
        self.assertIn("menu:typed-command-map", self.violations_with({path: source.replace("case 4: command = .requestQuit", "case 4: return")}))
        self.assertIn("menu:private-content-reference", self.violations_with({path: source + "\n// model.document.title\n"}))

    def test_validator_requires_flush_before_irreversible_teardown(self) -> None:
        path = "PrivatePresenterApp/App/AppLifecycleCoordinator.swift"
        source = VALIDATOR.read(path)
        reordered = source.replace(
            "record(.flushPausedSnapshot)",
            "record(.unregisterHotKeys)\n        record(.flushPausedSnapshot)",
            1,
        )
        self.assertIn("lifecycle:ordered-markers", self.violations_with({path: reordered}))

    def test_validator_preserves_schema_dependencies_entitlements_and_panel_defaults(self) -> None:
        snapshot = "Packages/TeleprompterCore/Sources/TeleprompterCore/Persistence/PersistedSnapshot.swift"
        self.assertIn(
            "schema:persisted-snapshot-version",
            self.violations_with({snapshot: VALIDATOR.read(snapshot).replace("currentSchemaVersion = 1", "currentSchemaVersion = 2")}),
        )
        project = VALIDATOR.read("project.yml").replace("- sdk: Carbon.framework", "- sdk: Network.framework")
        self.assertIn("dependency:project-yml-changed", self.violations_with({"project.yml": project}))
        entitlements = "PrivatePresenterApp/Resources/PrivatePresenter.entitlements"
        self.assertIn(
            "entitlement:non-sandbox-surface",
            self.violations_with({entitlements: VALIDATOR.read(entitlements) + "\ncom.apple.security.network.client\n"}),
        )


if __name__ == "__main__":
    unittest.main()
