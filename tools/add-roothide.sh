#!/usr/bin/env bash
# add-roothide.sh — add the RootHide jailbreak package scheme to a TheosWin install.
# Ports roothide/theos's changes onto the Windows-patched upstream theos WITHOUT
# touching Leeksov's Windows patches (roothide only adds vendor/mod/roothide +
# a tiny makefiles/instance/rules.mk change — verified non-overlapping).
#
# After this, build a RootHide tweak with:  make THEOS_PACKAGE_SCHEME=roothide
#
# Honest limits on Windows: the roothide SCHEME (install_name @loader_path/.jbroot…,
# arm64e, -lroothide warning) applies at compile/link time and works. The final
# .deb PACKAGING uses the same dpkg-deb stub limitation as all Theos-on-Windows —
# `make package` may not emit a full .deb; the built binary is still correct.
# The -lroothide runtime lib (roothide API) ships with the RootHide bootstrap SDK,
# not the stock iOS SDK; plain hooking tweaks don't need it. Test on a RootHide
# device to confirm end-to-end.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${THEOS:=$HOME/.theos/theos}"
[ -d "$THEOS/makefiles" ] || { echo "add-roothide: \$THEOS not found ($THEOS). Install TheosWin first."; exit 1; }

# 1. install the roothide package-scheme module
DST="$THEOS/vendor/mod/roothide"
mkdir -p "$DST"
cp -r "$HERE/../roothide-support/vendor-mod-roothide/." "$DST/"
echo "add-roothide: installed scheme module -> $DST"

# 2. patch makefiles/instance/rules.mk (idempotent)
RULES="$THEOS/makefiles/instance/rules.mk"
if grep -q 'THEOS_PACKAGE_SCHEME),roothide' "$RULES" 2>/dev/null; then
    echo "add-roothide: rules.mk already patched"
else
    # (a) roothide uses -lroothide, not -lroot: guard the -lroot line
    perl -0pi -e 's/(ifeq \(\$\(THEOS_TARGET_NAME\),iphone\)\n)(\t?_THEOS_INTERNAL_LDFLAGS \+= -lroot\$\(ABI_SUFFIX\)\n)(endif\n)/$1ifneq (\$(THEOS_PACKAGE_SCHEME),roothide)\n$2endif\n$3/' "$RULES"
    # (b) emit a THEOS_PACKAGE_SCHEME_<SCHEME> define (roothide's api headers use it)
    perl -0pi -e 's/(_THEOS_INTERNAL_CFLAGS \+= -D THEOS_PACKAGE_INSTALL_PREFIX="\\"\$\(THEOS_PACKAGE_INSTALL_PREFIX\)\\""\n)/$1_THEOS_INTERNAL_CFLAGS += -D THEOS_PACKAGE_SCHEME_\$(shell echo \$(or \$(THEOS_PACKAGE_SCHEME),rootful) | tr a-z A-Z)="1"\n/' "$RULES"
    if grep -q 'THEOS_PACKAGE_SCHEME),roothide' "$RULES"; then
        echo "add-roothide: patched rules.mk"
    else
        echo "add-roothide: WARNING rules.mk patch did not apply (upstream layout changed) — apply manually, see roothide-support/rules.mk.patch note"
    fi
fi
echo "add-roothide: done. Build with:  make THEOS_PACKAGE_SCHEME=roothide"
