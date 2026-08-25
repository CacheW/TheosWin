#!/usr/bin/env bash
# install-sdks.sh [16.5|18.6|26.5|all] — install pre-patched iOS SDKs from
# TheosWin's own sdks-v1 release into $THEOS/sdks/. Self-contained: these are
# already Windows-materialized (framework symlinks resolved), so no re-patching.
#
#   install-sdks.sh            # all three
#   install-sdks.sh 18.6 26.5  # just those
#
# The release is PRIVATE, so this uses `gh` (authenticated) to download. If you
# make the release public, swap to a plain curl of the asset URL.
set -e
: "${THEOS:=$HOME/.theos/theos}"
REPO="CacheW/TheosWin"; TAG="sdks-v1"
GH="${GH:-$(command -v gh || echo '/c/Program Files/GitHub CLI/gh.exe')}"
[ -d "$THEOS/makefiles" ] || { echo "install-sdks: \$THEOS not found ($THEOS). Install TheosWin first."; exit 1; }

declare -A ASSET=(
  [16.5]=iPhoneOS16.5-windows.sdk.tar.gz
  [18.6]=iPhoneOS18.6-windows.sdk.tar.gz
  [26.5]=iPhoneOS26.5-windows.sdk.tar.gz
)
want=("$@")
[ ${#want[@]} -eq 0 ] && want=(all)
[ "${want[0]}" = "all" ] && want=(16.5 18.6 26.5)

mkdir -p "$THEOS/sdks"
for v in "${want[@]}"; do
  f="${ASSET[$v]}"
  if [ -z "$f" ]; then echo "install-sdks: unknown SDK '$v' (have: 16.5 18.6 26.5)"; continue; fi
  echo "==> iPhoneOS$v.sdk"
  "$GH" release download "$TAG" --repo "$REPO" --pattern "$f" --dir "$THEOS/sdks" --clobber
  tar --force-local -xzf "$THEOS/sdks/$f" -C "$THEOS/sdks/"
  rm -f "$THEOS/sdks/$f"
  if [ -f "$THEOS/sdks/iPhoneOS$v.sdk/SDKSettings.plist" ]; then
    echo "    installed -> $THEOS/sdks/iPhoneOS$v.sdk"
  else
    echo "    WARNING: extraction looks incomplete"
  fi
done
echo "Done. Select per project with e.g.  TARGET = iphone:clang:18.6:14.5  (16.5 is the safe default)."
