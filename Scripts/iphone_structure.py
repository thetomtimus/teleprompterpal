"""Additive iPhone dependency checks; historical evidence still belongs to the Mac validator."""
from __future__ import annotations
import re
from pathlib import Path

MAC_TARGETS = ("PrivatePresenter", "PrivatePresenterAppTests", "PrivatePresenterUITests")
PORTABLE_MOVES = {
    f"Packages/TeleprompterCore/Sources/TeleprompterCore/{path}":
    f"Packages/TeleprompterCore/Sources/PromptingCore/{path}"
    for path in ("Models/ScriptDocument.swift", "Models/ReadingAnchor.swift", "Scrolling/ScrollEngine.swift",
                 "Scrolling/ScrollCommand.swift", "Scrolling/ReadingPositionMapper.swift")
}

def block(source: str, key: str, indent: int = 0) -> str:
    lines = source.splitlines()
    matches = [i for i, line in enumerate(lines) if line == " " * indent + key + ":"]
    if len(matches) != 1:
        return ""
    start = matches[0]
    end = start + 1
    while end < len(lines):
        line = lines[end]
        if line.strip() and len(line) - len(line.lstrip()) <= indent:
            break
        end += 1
    return "\n".join(lines[start:end]).rstrip()

def mac_project_compatible(current: str, baseline: str) -> bool:
    if block(current, "options") != block(baseline, "options") or current.splitlines()[0] != baseline.splitlines()[0]:
        return False
    expected_settings = block(baseline, "settings").replace('    MACOSX_DEPLOYMENT_TARGET: "14.0"\n', "")
    if block(current, "settings") != expected_settings or block(current, "configs") != block(baseline, "configs"):
        return False
    if block(current, "configFiles"):
        return False
    current_targets, old_targets = block(current, "targets"), block(baseline, "targets")
    for name in MAC_TARGETS:
        expected = block(old_targets, name, 2).replace(
            '    deploymentTarget: "14.0"\n',
            '    deploymentTarget: "14.0"\n    configFiles:\n      Debug: Config/Debug.xcconfig\n      Release: Config/Release.xcconfig\n')
        if block(current_targets, name, 2) != expected:
            return False
    if block(block(current, "schemes"), "PrivatePresenter", 2) != block(block(baseline, "schemes"), "PrivatePresenter", 2):
        return False
    return block(block(current, "packages"), "TeleprompterCore", 2) == block(block(baseline, "packages"), "TeleprompterCore", 2)

def core_package_compatible(source: str) -> bool:
    text = re.sub(r"//[^\n]*", "", source)
    if any(word in text for word in (".package(", ".binaryTarget", ".plugin", "unsafeFlags", "path:", "sources:", "exclude:")):
        return False
    products = re.findall(r'\.library\s*\(\s*name:\s*"([^"]+)"\s*,\s*targets:\s*\[\s*"([^"]+)"\s*\]\s*\)', text)
    if sorted(products) != [("PromptingCore", "PromptingCore"), ("TeleprompterCore", "TeleprompterCore")]:
        return False
    targets = re.findall(r'\.target\s*\(([^)]*)\)', text)
    normalized = sorted(re.sub(r"\s+", "", target) for target in targets)
    if normalized != sorted(['name:"PromptingCore"', 'name:"TeleprompterCore",dependencies:["PromptingCore"]']):
        return False
    tests = re.findall(r'\.testTarget\s*\(([^)]*)\)', text)
    if sorted(re.sub(r"\s+", "", test).rstrip(",") for test in tests) != sorted([
        'name:"PromptingCoreTests",dependencies:["PromptingCore","TeleprompterCore"]',
        'name:"TeleprompterCoreTests",dependencies:["TeleprompterCore"]',
    ]):
        return False
    return bool(re.search(r'platforms:\s*\[\s*\.macOS\(\.v14\)\s*,\s*\.iOS\(\.v18\)\s*\]', text)
                and re.search(r'swiftLanguageModes:\s*\[\s*\.v6\s*\]', text))

def validate_phone_boundary(root: Path, read) -> list[str]:
    violations = []
    project = read("project.yml")
    targets = block(project, "targets")
    phone = block(targets, "TeleprompterPhone", 2)
    for marker in ('platform: iOS', 'deploymentTarget: "18.0"', 'product: PromptingCore',
                   'TARGETED_DEVICE_FAMILY: "1"', 'SWIFT_DEFAULT_ACTOR_ISOLATION: nonisolated',
                   'excludes: [PrototypeEntry.swift, Info.plist]'):
        if marker not in phone:
            violations.append("phone:missing:" + marker)
    if any(marker in phone for marker in ("product: TeleprompterCore", "Carbon.framework", "Config/Debug.xcconfig", "MACOSX_DEPLOYMENT_TARGET")):
        violations.append("phone:mac-dependency")
    if not core_package_compatible(read("Packages/TeleprompterCore/Package.swift")):
        violations.append("core:dependency-boundary")
    for old in PORTABLE_MOVES:
        name = Path(old).stem
        names = {"ReadingPositionMapper": ("ReadingPositionAdjustmentReason", "ReadingPositionMapping", "ReadingPositionMapper"),
                 "ScrollCommand": ("ScrollSuspensionReason", "ScrollStopReason", "ScrollCommand", "ScrollTransition")}.get(name, (name,))
        expected = "import PromptingCore\n\n" + "".join(f"public typealias {item} = PromptingCore.{item}\n" for item in names)
        if read(old) != expected:
            violations.append("core:compatibility-alias:" + old)
    for target, allowed in (("PromptingCore", {"Foundation"}), ("TeleprompterCore", {"Foundation", "PromptingCore"})):
        directory = root / "Packages/TeleprompterCore/Sources" / target
        sources = list(directory.rglob("*.swift"))
        if not sources:
            violations.append("core:missing:" + target)
        for path in sources:
            text = read(path.relative_to(root).as_posix())
            imports = set(re.findall(r'^\s*(?:@preconcurrency\s+)?import\s+([\w.]+)', text, re.M))
            if not imports.issubset(allowed):
                violations.append("core:import:" + path.relative_to(root).as_posix())
            if re.search(r'\b(URLSession|NWConnection|NWListener|WKWebView|HTTPClient)\b', text):
                violations.append("core:network-surface:" + path.relative_to(root).as_posix())
    for directory in (root / "iPhoneApp", root / "iPhonePrototype/App"):
        for path in directory.glob("*.swift"):
            if re.search(r'^import (TeleprompterCore|AppKit|Carbon)\b', read(path.relative_to(root).as_posix()), re.M):
                violations.append("phone:forbidden-import:" + path.relative_to(root).as_posix())
    for name in ("TeleprompterPhoneTests", "TeleprompterPhoneUITests"):
        if 'platform: iOS' not in block(targets, name, 2):
            violations.append("phone:missing-test-target:" + name)
    packages = block(project, "packages")
    expected_packages = {"TeleprompterCore": "Packages/TeleprompterCore", "PhoneLibrary": "Packages/PhoneLibrary",
                         "PrototypeSupport": "iPhonePrototype/Support"}
    if set(re.findall(r"^  (\w+):$", packages, re.M)) != set(expected_packages):
        violations.append("phone:package-inventory")
    for name, path in expected_packages.items():
        if block(packages, name, 2) != f"  {name}:\n    path: {path}":
            violations.append("phone:package-path:" + name)
    for path in ("Packages/PhoneLibrary/Package.swift", "iPhonePrototype/Support/Package.swift"):
        manifest = re.sub(r"//[^\n]*", "", read(path))
        if re.search(r'url:|\.binaryTarget|\.plugin|unsafeFlags|\.package\((?!path: "../TeleprompterCore"\))', manifest):
            violations.append("phone:external-package:" + path)
    for directory in (root / "iPhoneApp", root / "iPhonePrototype/App",
                      root / "iPhonePrototype/Support/Sources", root / "Packages/PhoneLibrary/Sources"):
        for path in directory.rglob("*.swift"):
            source = read(path.relative_to(root).as_posix())
            if re.search(r'\b(URLSession|NWConnection|NWListener|WKWebView|HTTPClient)\b|^\s*import\s+(Network|WebKit)\b', source, re.M):
                violations.append("phone:network-surface:" + path.relative_to(root).as_posix())
            if directory.name == "Sources" and "PhoneLibrary" in str(directory):
                imports = set(re.findall(r'^\s*import\s+([\w.]+)', source, re.M))
                if not imports.issubset({"Foundation", "PromptingCore"}):
                    violations.append("library:import:" + path.relative_to(root).as_posix())
    return violations
