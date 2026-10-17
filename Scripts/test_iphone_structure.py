#!/usr/bin/env python3
"""Mutation checks for the P2 extraction, independent of old handoff artifacts."""
from pathlib import Path
import subprocess
import unittest
from iphone_structure import core_package_compatible, mac_project_compatible, validate_phone_boundary

ROOT = Path(__file__).resolve().parents[1]
BASELINE = "20283198dfd6c5e645b4ad20cd52b7e1445fd833"

def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

class PhoneBoundaryTests(unittest.TestCase):
    def violations(self, edits):
        return validate_phone_boundary(ROOT, lambda path: edits.get(path, read(path)))

    def test_current_phone_boundary(self):
        self.assertEqual(self.violations({}), [])

    def test_mac_configuration_preserved_with_target_scoped_configs(self):
        baseline = subprocess.check_output(["git", "show", f"{BASELINE}:project.yml"], cwd=ROOT, text=True)
        source = read("project.yml")
        self.assertTrue(mac_project_compatible(source, baseline))
        for old, new in (("Carbon.framework", "Network.framework"),
                         ("com.apple.security.app-sandbox: true", "com.apple.security.app-sandbox: false"),
                         ("Debug: Config/Debug.xcconfig", "Debug: Config/Release.xcconfig"),
                         ("PrivatePresenterUITests: [test]", "PrivatePresenterUITests: all"),
                         ("path: Packages/TeleprompterCore", "path: Packages/OtherCore"),
                         ('macOS: "14.0"', 'macOS: "15.0"')):
            with self.subTest(new=new):
                self.assertFalse(mac_project_compatible(source.replace(old, new, 1), baseline))

    def test_core_package_rejects_dependency_and_test_target_drift(self):
        source = read("Packages/TeleprompterCore/Package.swift")
        self.assertTrue(core_package_compatible(source))
        for old, new in (('.target(name: "PromptingCore")', '.target(name: "PromptingCore", dependencies: ["NetworkClient"])'),
                         ('dependencies: ["TeleprompterCore"]', 'dependencies: ["PromptingCore"]'),
                         (".iOS(.v18)", ".iOS(.v19)"),
                         ('name: "TeleprompterCoreTests"', 'name: "RemovedLegacyTests"'),
                         ("targets: [", 'dependencies: [.package(url: "https://example.invalid/vendor", from: "1.0.0")], targets: [')):
            with self.subTest(new=new):
                self.assertFalse(core_package_compatible(source.replace(old, new, 1)))

    def test_new_portable_core_rejects_platform_and_network_imports(self):
        path = "Packages/TeleprompterCore/Sources/PromptingCore/Models/ScriptDocument.swift"
        for module in ("AppKit", "UIKit", "Network", "TeleprompterCore"):
            with self.subTest(module=module):
                self.assertIn("core:import:" + path, self.violations({path: read(path) + f"\nimport {module}\n"}))
        self.assertIn("core:network-surface:" + path, self.violations({path: read(path) + "\nlet client = URLSession.shared\n"}))

    def test_compatibility_alias_cannot_hide_implementation_or_prohibited_code(self):
        path = "Packages/TeleprompterCore/Sources/TeleprompterCore/Models/ScriptDocument.swift"
        self.assertIn("core:compatibility-alias:" + path, self.violations({path: read(path) + "\nlet hidden = URLSession.shared\n"}))

    def test_phone_cannot_link_desktop_core_or_carbon(self):
        source = read("project.yml")
        for replacement in ("product: TeleprompterCore", "sdk: Carbon.framework"):
            with self.subTest(replacement=replacement):
                mutated = source.replace("product: PromptingCore", replacement, 1)
                self.assertIn("phone:mac-dependency", self.violations({"project.yml": mutated}))

    def test_phone_and_library_network_surfaces_rejected(self):
        for path in ("iPhoneApp/LibraryModel.swift", "Packages/PhoneLibrary/Sources/PhoneLibrary/LibraryStore.swift",
                     "iPhonePrototype/App/CaptureService.swift", "iPhonePrototype/Support/Sources/PrototypeSupport/TakeStore.swift"):
            with self.subTest(path=path):
                self.assertIn("phone:network-surface:" + path, self.violations({path: read(path) + "\nlet client = URLSession.shared\n"}))

    def test_phone_target_and_tests_must_remain_ios(self):
        source = read("project.yml")
        self.assertTrue(self.violations({"project.yml": source.replace('deploymentTarget: "18.0"', 'deploymentTarget: "26.0"', 1)}))
        self.assertIn("phone:missing-test-target:TeleprompterPhoneUITests", self.violations({
            "project.yml": source.replace("TeleprompterPhoneUITests:\n    type: bundle.ui-testing\n    platform: iOS", "TeleprompterPhoneUITests:\n    type: bundle.ui-testing\n    platform: macOS")}))

    def test_vendor_package_and_local_package_redirection_rejected(self):
        project = read("project.yml").replace("path: Packages/PhoneLibrary", "url: https://example.invalid/library")
        self.assertIn("phone:package-path:PhoneLibrary", self.violations({"project.yml": project}))
        path = "Packages/PhoneLibrary/Package.swift"
        manifest = read(path).replace('path: "../TeleprompterCore"', 'url: "https://example.invalid/core", from: "1.0.0"')
        self.assertIn("phone:external-package:" + path, self.violations({path: manifest}))

if __name__ == "__main__":
    unittest.main()
