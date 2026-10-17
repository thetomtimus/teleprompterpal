#!/usr/bin/env python3
"""Audit a local iPhone archive and App Store export without uploading anything."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import zipfile


def run(*args):
    return subprocess.check_output(args, stderr=subprocess.STDOUT)


def audit(archive, ipa):
    archive_info = plistlib.loads((archive / "Info.plist").read_bytes())
    app = archive / "Products" / archive_info["ApplicationProperties"]["ApplicationPath"]
    info = plistlib.loads((app / "Info.plist").read_bytes())
    assert info["CFBundleIdentifier"] == "com.secondwind.teleprompter.prototype"
    assert info["ITSAppUsesNonExemptEncryption"] is False
    assert info["MinimumOSVersion"] == "18.0"
    assert info["UIDeviceFamily"] == [1]
    assert info["CFBundleIcons"]["CFBundlePrimaryIcon"]["CFBundleIconName"] == "AppIcon"
    for key in ["NSCameraUsageDescription", "NSMicrophoneUsageDescription", "NSPhotoLibraryAddUsageDescription"]:
        assert info[key]
    privacy = plistlib.loads((app / "PrivacyInfo.xcprivacy").read_bytes())
    reasons = {i["NSPrivacyAccessedAPIType"]: i["NSPrivacyAccessedAPITypeReasons"]
               for i in privacy["NSPrivacyAccessedAPITypes"]}
    for category, reason in [("UserDefaults", "CA92.1"), ("FileTimestamp", "C617.1"),
                             ("DiskSpace", "E174.1"), ("SystemBootTime", "35F9.1")]:
        assert reason in reasons["NSPrivacyAccessedAPICategory" + category]
    assert privacy["NSPrivacyTracking"] is False
    assert privacy["NSPrivacyCollectedDataTypes"] == []
    run("codesign", "--verify", "--deep", "--strict", str(app))
    binary = app / info["CFBundleExecutable"]
    binary_bytes = binary.read_bytes()
    for probe in [b"--p2-test-root", b"--p5-local-paywall", b"local.teleprompter.pro.monthly", b"local.teleprompter.pro.annual",
                  b"--p4b-stage-crop-fixtures", b"--physical-probe"]:
        assert probe not in binary_bytes, probe
    assert b"StoreKitTest" not in run("xcrun", "otool", "-L", str(binary))
    dwarf = archive / "dSYMs" / (app.name + ".dSYM")
    uuids = lambda p: set(re.findall(rb"UUID: ([0-9A-F-]+)", run("xcrun", "dwarfdump", "--uuid", str(p))))
    assert uuids(binary) == uuids(dwarf) and uuids(binary)
    with zipfile.ZipFile(ipa) as bundle, tempfile.TemporaryDirectory(prefix="teleprompter-profile-") as temp:
        names = bundle.namelist()
        plist_name = next(n for n in names if n.endswith(".app/Info.plist") and n.count("/") == 2)
        shipped = plistlib.loads(bundle.read(plist_name))
        for key in ["CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion"]:
            assert shipped[key] == info[key]
        profile_name = next(n for n in names if n.endswith(".app/embedded.mobileprovision"))
        profile_file = Path(temp) / "profile.mobileprovision"
        profile_file.write_bytes(bundle.read(profile_name))
        profile = plistlib.loads(run("security", "cms", "-D", "-i", str(profile_file)))
        assert profile["TeamIdentifier"] == ["UDY74D56MB"]
        assert profile["Entitlements"]["get-task-allow"] is False
        assert profile["Entitlements"]["application-identifier"].endswith("." + info["CFBundleIdentifier"])
        assert not profile.get("ProvisionedDevices") and not profile.get("ProvisionsAllDevices")
        assert not any("storekit" in n.lower() or "xctest" in n.lower() or n.endswith(".swift") for n in names)
    return {
        "version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"],
        "bundleID": info["CFBundleIdentifier"], "workingDisplayName": info["CFBundleDisplayName"],
        "team": profile["TeamIdentifier"][0], "distributionProfile": True, "debuggerAllowed": False,
        "icon": "AppIcon", "privacyReasons": reasons, "nonExemptEncryption": False,
        "noDebugFixtures": True, "matchingDSYM": True,
        "archive": str(archive.resolve()), "ipa": str(ipa.resolve()),
        "ipaBytes": ipa.stat().st_size, "ipaSHA256": hashlib.sha256(ipa.read_bytes()).hexdigest(),
        "appleServerValidation": "not performed by this local audit",
        "appRecordStatus": "not queried by this local audit",
        "uploadedByThisAudit": False, "publishedByThisAudit": False,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = json.dumps(audit(args.archive, args.ipa), indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report)
    print(report, end="")
