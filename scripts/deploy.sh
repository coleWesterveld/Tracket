#!/usr/bin/env bash
#
# Build and deploy Tracket as dev or prod. No pbxproj mutation, ever.
#
#   scripts/deploy.sh dev [device]   Run a release build on the device as
#                                    "Tracket Dev" (com.example.coleAppTesting).
#                                    Updates the existing dev install in place,
#                                    so its database is preserved. Device
#                                    defaults to Kevin.
#   scripts/deploy.sh prod           Build the App Store .ipa as "Tracket"
#                                    (com.cole.tracket).
#
# How it works: ios/Flutter/AppIdentity.xcconfig resolves the bundle ID and
# display name. Prod is the committed default; dev mode writes the gitignored
# override ios/Flutter/AppIdentity-Local.xcconfig for the duration of the run
# and removes it on exit. A plain `flutter build ipa` outside this script is
# therefore always prod.

set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="$HOME/flutter/bin:$PATH"

OVERRIDE=ios/Flutter/AppIdentity-Local.xcconfig
MODE="${1:-}"

usage() { echo "usage: scripts/deploy.sh dev [device] | prod"; exit 1; }

case "$MODE" in
  dev)
    DEVICE="${2:-Kevin}"
    printf '#include "AppIdentity-Dev.xcconfig"\n' > "$OVERRIDE"
    trap 'rm -f "$OVERRIDE"' EXIT
    echo "==> Deploying DEV build (com.example.coleAppTesting) to $DEVICE"
    flutter run --release -d "$DEVICE"
    ;;
  prod)
    rm -f "$OVERRIDE"
    echo "==> Building PROD .ipa (com.cole.tracket)"
    flutter build ipa
    echo "==> Archive at build/ios/ipa. Upload via Transporter or xcrun altool."
    ;;
  *)
    usage
    ;;
esac
