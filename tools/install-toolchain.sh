#!/usr/bin/env bash
# install-toolchain.sh — install the PINNED Windows iOS toolchain (LLVM 19) from
# TheosWin's own toolchain-v1 release, for byte-for-byte reproducibility.
#
# Why: the base install.sh pulls the toolchain from Leeksov's 'latest' release,
# which could change if they publish a newer LLVM. This installs the exact copy
# pinned in this repo, so a fresh machine matches your current setup precisely.
#
#   tools/install-toolchain.sh
#
# Installs to ~/.theos/toolchain/windows/iphone AND copies into $THEOS (the theos
# framework) the same way the base installer does.
set -e
PREFIX="$HOME/.theos"
: "${THEOS:=$PREFIX/theos}"
REPO="CacheW/TheosWin"; TAG="toolchain-v1"; ASSET="theos-windows-toolchain-pinned.tar.gz"
GH="${GH:-$(command -v gh || echo '/c/Program Files/GitHub CLI/gh.exe')}"

echo "==> downloading pinned toolchain from $REPO ($TAG)"
mkdir -p "$PREFIX"
"$GH" release download "$TAG" --repo "$REPO" --pattern "$ASSET" --dir "$PREFIX" --clobber

echo "==> extracting to $PREFIX (creates toolchain/windows/iphone)"
tar --force-local -xzf "$PREFIX/$ASSET" -C "$PREFIX"
rm -f "$PREFIX/$ASSET"

# mirror into the theos framework (base installer Step 4)
if [ -d "$THEOS" ]; then
  TCDST="$THEOS/toolchain/windows/iphone"
  mkdir -p "$TCDST/bin" "$TCDST/lib"
  cp -rf "$PREFIX/toolchain/windows/iphone/bin/." "$TCDST/bin/" 2>/dev/null || true
  cp -rf "$PREFIX/toolchain/windows/iphone/lib/." "$TCDST/lib/" 2>/dev/null || true
fi

if [ -x "$PREFIX/toolchain/windows/iphone/bin/clang.exe" ]; then
  echo "==> pinned toolchain installed:"
  "$PREFIX/toolchain/windows/iphone/bin/clang.exe" --version 2>/dev/null | head -1
else
  echo "==> WARNING: clang.exe not found after extract"
fi
