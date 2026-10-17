#!/usr/bin/env python3
"""Assert actual native-flow journals, using only UUID roots printed by the UI tests."""
import json
import re
import sys
from collections import Counter
from pathlib import Path


def verify(container: Path, log: str) -> dict:
    roots = dict(re.findall(r"P5D_EVENT_ROOT scenario=(activation|recovery) id=([0-9A-F-]{36})", log))
    assert set(roots) == {"activation", "recovery"}, "Both P5D native roots must execute"
    result = {}
    for scenario, identifier in roots.items():
        path = container / "Library/Application Support/LocalEvents/UITests" / identifier / "events.json"
        raw = path.read_bytes()
        journal = json.loads(raw)
        assert journal["schemaVersion"] == 1 and len(raw) <= 512 * 1024
        events = journal["events"]
        assert 0 < len(events) <= 500
        assert all(event["runtime"] == "simulator" for event in events)
        allowed = {"scriptReady", "recordingStarted", "recordingFinished", "exportResult", "paywallViewed", "purchaseResult"}
        assert all(set(event) == {"operationID", "at", "runtime", "payload"} for event in events)
        assert all(len(event["payload"]) == 1 and set(event["payload"]) <= allowed for event in events)
        assert not any(value in raw for value in [b"P5D local test", b"This script stays", b".mov", b".mp4", b"local.teleprompter.pro.", b"/Users/", b"assetIdentifier"])
        kinds = Counter(next(iter(event["payload"])) for event in events)
        exports = [e["payload"]["exportResult"] | {"operationID": e["operationID"]} for e in events if "exportResult" in e["payload"]]
        if scenario == "activation":
            assert kinds == {"scriptReady": 1, "recordingStarted": 1, "recordingFinished": 1,
                             "exportResult": 4, "paywallViewed": 2, "purchaseResult": 2}, kinds
            started = next(e for e in events if "recordingStarted" in e["payload"])
            finished = next(e for e in events if "recordingFinished" in e["payload"])
            assert started["operationID"] == finished["operationID"]
            assert started["payload"]["recordingStarted"]["access"] == "verified"
            assert finished["payload"]["recordingFinished"]["outcome"] == "valid"
            assert {(e["stage"], e["outcome"]) for e in exports} == {
                ("file", "ready"), ("photos", "completed"), ("files", "completed"), ("share", "completed")}
            assert all(e["trimmed"] and e["cropped"] and e["ratio"] == "square" for e in exports)
            purchases = [e["payload"]["purchaseResult"] for e in events if "purchaseResult" in e["payload"]]
            assert {(e["action"], e["outcome"]) for e in purchases} == {("purchase", "verified"), ("restore", "restored")}
            assert next(e for e in purchases if e["action"] == "purchase")["store"] == "xcode"
        else:
            assert kinds == {"exportResult": 4}, kinds
            assert Counter((e["stage"], e["outcome"]) for e in exports) == {
                ("file", "cancelled"): 1, ("file", "ready"): 1,
                ("photos", "unknown"): 1, ("photos", "completed"): 1}
            unknown = next(e for e in exports if e["outcome"] == "unknown")
            completed = next(e for e in exports if e["stage"] == "photos" and e["outcome"] == "completed")
            assert unknown["operationID"] != completed["operationID"], "Explicit retry needs a new attempt"
        result[scenario] = {"root": identifier, "eventCount": len(events), "kinds": dict(kinds)}
    return result


if __name__ == "__main__":
    print(json.dumps(verify(Path(sys.argv[1]), Path(sys.argv[2]).read_text()), indent=2))
