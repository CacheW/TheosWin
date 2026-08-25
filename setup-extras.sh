#!/usr/bin/env bash
# setup-extras.sh — one command to add TheosWin's extras on top of a base install.
# Run install.sh first (base Theos), then this for the optional pieces.
#
#   ./setup-extras.sh --all                       # SDKs + Swift + RootHide
#   ./setup-extras.sh --sdks all                  # just the extra iOS SDKs
#   ./setup-extras.sh --sdks 18.6,26.5 --roothide
#   ./setup-extras.sh --swift                     # just the swift.org toolchain
#
# Flags:
#   --sdks <all|16.5,18.6,26.5>  install pre-patched SDKs from the sdks-v1 release
#   --swift                      download + silent-install swift.org 6.1.2 (Windows)
#   --roothide                   add the RootHide package scheme
#   --toolchain                  install the PINNED LLVM 19 (reproducibility; not in --all)
#   --all                        = --sdks all --swift --roothide
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${THEOS:=$HOME/.theos/theos}"

DO_SDKS=""; DO_SWIFT=0; DO_ROOTHIDE=0; DO_TOOLCHAIN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --all)       DO_SDKS="all"; DO_SWIFT=1; DO_ROOTHIDE=1 ;;
    --sdks)      DO_SDKS="${2:-all}"; shift ;;
    --swift)     DO_SWIFT=1 ;;
    --roothide)  DO_ROOTHIDE=1 ;;
    --toolchain) DO_TOOLCHAIN=1 ;;
    -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "setup-extras: unknown arg '$1' (see --help)"; exit 1 ;;
  esac
  shift
done
[ -z "$DO_SDKS$DO_SWIFT$DO_ROOTHIDE" ] && [ "$DO_TOOLCHAIN" = 0 ] && { grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0; }
[ -d "$THEOS/makefiles" ] || { echo "setup-extras: \$THEOS not found ($THEOS). Run install.sh first."; exit 1; }

# ---- Pinned toolchain (reproducibility) ----
if [ "$DO_TOOLCHAIN" = 1 ]; then
  echo "== Pinned toolchain (LLVM 19) =="
  bash "$HERE/tools/install-toolchain.sh"
fi

# ---- SDKs ----
if [ -n "$DO_SDKS" ]; then
  echo "== SDKs: $DO_SDKS =="
  bash "$HERE/tools/install-sdks.sh" $(echo "$DO_SDKS" | tr ',' ' ')
fi

# ---- Swift toolchain (swift.org, Windows) ----
if [ "$DO_SWIFT" = 1 ]; then
  echo "== Swift toolchain (swift.org 6.1.2, ~540 MB) =="
  if find "$HOME/AppData/Local/Programs/Swift/Toolchains" -iname swiftc.exe >/dev/null 2>&1; then
    echo "   swiftc already installed — skipping download"
  else
    TMP="$(mktemp -d)"; EXE="$TMP/swift-6.1.2-windows10.exe"
    echo "   downloading..."
    curl -fL "https://download.swift.org/swift-6.1.2-release/windows10/swift-6.1.2-RELEASE/swift-6.1.2-RELEASE-windows10.exe" -o "$EXE" --progress-bar
    echo "   silent install..."
    "$EXE" -quiet -norestart || true
    rm -rf "$TMP"
  fi
  echo "   Swift-for-iOS ready. Compile pure-Swift/@_cdecl with: tools/swiftc-ios (see docs/Swift.md)"
  echo "   NOTE: import UIKit/Foundation from Swift is NOT supported on Windows (needs Apple's swiftc)."
fi

# ---- RootHide package scheme ----
if [ "$DO_ROOTHIDE" = 1 ]; then
  echo "== RootHide package scheme =="
  bash "$HERE/tools/add-roothide.sh"
fi

echo ""
echo "setup-extras: done."
