#!/bin/sh
set -eu
# Debug iteration remains available; distribution builds require a current review.
if [ "${CONFIGURATION:-}" = "Release" ]; then
  /usr/bin/python3 -B "${SRCROOT:?Missing Xcode SRCROOT}/Scripts/help_sync.py" check
fi
