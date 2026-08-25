#!/usr/bin/env bash
# Theos for Windows - One-Click Installer
# Downloads everything from GitHub. Installs to ~/.theos
# Usage: bash install.sh

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
info()  { printf "${BLUE}==>${NC} %s\n" "$1"; }
ok()    { printf "${GREEN}==>${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}==>${NC} %s\n" "$1"; }
error() { printf "${RED}==>${NC} %s\n" "$1"; exit 1; }

REPO="Leeksov/theos-windows"
TOOLCHAIN_ASSET="theos-windows-toolchain.tar.gz"
PREFIX="$HOME/.theos"

echo ""
printf "${BOLD}  Theos for Windows${NC}\n"
printf "  Build iOS tweaks natively on Windows\n"
echo ""

# ── Checks ─────────────────────────────────────────────────────────
info "Checking prerequisites..."
command -v git  >/dev/null 2>&1 || error "Git not found. Install: https://git-scm.com/download/win"
command -v curl >/dev/null 2>&1 || error "curl not found."
command -v tar  >/dev/null 2>&1 || error "tar not found."

PYTHON=""
for p in python3 python; do command -v "$p" >/dev/null 2>&1 && PYTHON="$p" && break; done
if [ -z "$PYTHON" ]; then
    for p in "/c/Users/$USER/AppData/Local/Programs/Python/"*/python.exe; do
        [ -x "$p" ] && PYTHON="$p" && break
    done
fi

ok "Prerequisites OK"
info "Install path: $PREFIX"
mkdir -p "$PREFIX"

# ── Step 1: Download pre-built toolchain from GitHub Releases ──────
if [ -f "$PREFIX/toolchain/windows/iphone/bin/clang.exe" ]; then
    ok "Toolchain already installed"
else
    info "Downloading pre-built toolchain (~150 MB)..."
    curl -L "https://github.com/$REPO/releases/latest/download/$TOOLCHAIN_ASSET" \
        -o "$PREFIX/$TOOLCHAIN_ASSET" --progress-bar
    [ -s "$PREFIX/$TOOLCHAIN_ASSET" ] || error "Download failed"

    info "Extracting..."
    tar xzf "$PREFIX/$TOOLCHAIN_ASSET" -C "$PREFIX"
    rm -f "$PREFIX/$TOOLCHAIN_ASSET"
    ok "Toolchain installed"
fi

# ── Step 2: Clone Theos from GitHub ────────────────────────────────
THEOS="$PREFIX/theos"
if [ -d "$THEOS/.git" ]; then
    ok "Theos already cloned"
else
    info "Cloning Theos..."
    git clone --recursive https://github.com/theos/theos.git "$THEOS"
fi
info "Updating submodules..."
(cd "$THEOS" && git submodule update --init --recursive 2>/dev/null) || true

# ── Step 3: Fix broken symlinks ────────────────────────────────────
info "Fixing Windows symlinks..."
cd "$THEOS"
for mapping in \
    "bin/logos.pl:vendor/logos/bin/logos.pl" \
    "bin/logify.pl:vendor/logos/bin/logify.pl" \
    "bin/dm.pl:vendor/dm.pl/dm.pl" \
    "bin/nic.pl:vendor/nic/bin/nic.pl" \
    "bin/nicify.pl:vendor/nic/bin/nicify.pl" \
    "bin/denicify.pl:vendor/nic/bin/denicify.pl" \
    "vendor/include/IOKit/IOKit.h:vendor/include/IOKit/IOKitLib.h"; do
    dst="${mapping%%:*}"; src="${mapping##*:}"
    if [ -f "$src" ]; then
        if [ -f "$dst" ] && [ "$(wc -l < "$dst" 2>/dev/null)" -le 2 ]; then
            head -1 "$dst" | grep -q '^\.\./\|^[A-Za-z].*\.[A-Za-z]' 2>/dev/null && cp "$src" "$dst"
        elif [ ! -f "$dst" ]; then
            mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"
        fi
    fi
done
mkdir -p bin/lib
cp -r vendor/logos/bin/lib/* bin/lib/ 2>/dev/null || true

# Fix substrate.h — copy real header from framework, not the broken symlink
REAL_SUBSTRATE="vendor/lib/CydiaSubstrate.framework/Headers/CydiaSubstrate.h"
if [ -f "$REAL_SUBSTRATE" ]; then
    cp "$REAL_SUBSTRATE" "vendor/include/CydiaSubstrate.h"
    cp "$REAL_SUBSTRATE" "vendor/include/substrate.h"
fi

ok "Symlinks fixed"

# ── Step 4: Install toolchain into Theos ───────────────────────────
info "Setting up toolchain..."
TCDST="$THEOS/toolchain/windows/iphone"
mkdir -p "$TCDST/bin" "$TCDST/lib"
cp -rn "$PREFIX/toolchain/windows/iphone/bin/"* "$TCDST/bin/" 2>/dev/null || \
cp -r "$PREFIX/toolchain/windows/iphone/bin/"* "$TCDST/bin/" 2>/dev/null
cp -rn "$PREFIX/toolchain/windows/iphone/lib/"* "$TCDST/lib/" 2>/dev/null || \
cp -r "$PREFIX/toolchain/windows/iphone/lib/"* "$TCDST/lib/" 2>/dev/null

# CydiaSubstrate stub
SUBSTRATE="$THEOS/vendor/lib/CydiaSubstrate.framework"
[ -f "$PREFIX/stubs/CydiaSubstrate.framework/CydiaSubstrate" ] && \
    cp "$PREFIX/stubs/CydiaSubstrate.framework/CydiaSubstrate" "$SUBSTRATE/CydiaSubstrate" && \
    rm -f "$SUBSTRATE/CydiaSubstrate.tbd" "$THEOS/vendor/lib/libsubstrate.tbd" 2>/dev/null
REAL_HDR="$SUBSTRATE/Headers/CydiaSubstrate.h"
[ -f "$REAL_HDR" ] && cp "$REAL_HDR" "$THEOS/vendor/include/CydiaSubstrate.h" \
    && cp "$REAL_HDR" "$THEOS/vendor/include/substrate.h"

# Rootless substrate stub
ROOTLESS="$THEOS/vendor/lib/iphone/rootless/CydiaSubstrate.framework"
if [ -d "$ROOTLESS" ]; then
    cp "$SUBSTRATE/CydiaSubstrate" "$ROOTLESS/CydiaSubstrate" 2>/dev/null
    rm -f "$ROOTLESS/CydiaSubstrate.tbd" "$THEOS/vendor/lib/iphone/rootless/libsubstrate.tbd" 2>/dev/null
fi
ok "Toolchain ready"

# ── Step 5: Install patched iOS SDK ───────────────────────────────
SDK_URL="https://github.com/Leeksov/theos-sdk-windows/releases/latest/download/iPhoneOS16.5-windows.sdk.tar.gz"

if ls "$THEOS/sdks/"iPhoneOS*.sdk/SDKSettings.plist >/dev/null 2>&1; then
    ok "iOS SDK already installed"
else
    info "Downloading patched iOS SDK (~30 MB)..."
    mkdir -p "$THEOS/sdks"
    curl -L "$SDK_URL" -o "$THEOS/sdks/sdk.tar.gz" --progress-bar
    [ -s "$THEOS/sdks/sdk.tar.gz" ] || error "SDK download failed"
    tar xzf "$THEOS/sdks/sdk.tar.gz" -C "$THEOS/sdks/"
    rm -f "$THEOS/sdks/sdk.tar.gz"
    ls "$THEOS/sdks/"iPhoneOS*.sdk/SDKSettings.plist >/dev/null 2>&1 && ok "iOS SDK installed" || error "SDK extraction failed"
fi

# ── Step 6: Install Strawberry Perl from GitHub ────────────────────
PERL_DIR="$PREFIX/strawberry-perl"
TOOLS="$PREFIX/tools-bin"

if [ -f "$PERL_DIR/perl/bin/perl.exe" ]; then
    ok "Strawberry Perl already installed"
else
    info "Downloading Strawberry Perl (~290 MB)..."
    PERL_URL=$(curl -sL "https://api.github.com/repos/StrawberryPerl/Perl-Dist-Strawberry/releases/latest" 2>/dev/null \
        | grep "browser_download_url.*portable.*zip" | head -1 | grep -o 'https://[^"]*')
    if [ -n "$PERL_URL" ]; then
        curl -L "$PERL_URL" -o /tmp/strawberry-perl.zip --progress-bar
        mkdir -p "$PERL_DIR"
        unzip -qo /tmp/strawberry-perl.zip -d "$PERL_DIR"
        rm -f /tmp/strawberry-perl.zip
        ok "Strawberry Perl installed"
    else
        warn "Could not download Perl. Logos (.x) won't work."
    fi
fi

# Perl wrapper
if [ -f "$PERL_DIR/perl/bin/perl.exe" ]; then
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$PERL_DIR/perl/bin/perl.exe" > "$TOOLS/perl"
    chmod +x "$TOOLS/perl"
fi

# ── Step 7: Patch Theos makefiles ──────────────────────────────────
info "Patching Theos..."

# Platform detection
COMMON_MK="$THEOS/makefiles/common.mk"
if ! grep -q 'MINGW%' "$COMMON_MK" 2>/dev/null; then
    sed -i '/^export _THEOS_PLATFORM = \$(uname_s)$/i\
ifneq ($(filter MINGW% MSYS% CYGWIN%,$(uname_s)),)\
export _THEOS_PLATFORM := Windows\
export _THEOS_OS := Windows\
else' "$COMMON_MK"
    sed -i '/^export _THEOS_OS = \$(if/a\
endif' "$COMMON_MK"
    ok "Patched platform detection"
fi

# Linker
DARWIN_TAIL="$THEOS/makefiles/targets/_common/darwin_tail.mk"
if ! grep -q 'ld64.lld' "$DARWIN_TAIL" 2>/dev/null; then
    sed -i '/^_THEOS_TARGET_LDFLAGS += -fuse-ld=\$(SDKBINPATH)\/\$(_THEOS_TARGET_SDK_BIN_PREFIX)ld$/a\
else ifneq ($(wildcard $(SDKBINPATH)/ld64.lld.exe),)\
_THEOS_TARGET_LDFLAGS += -B$(SDKBINPATH)' "$DARWIN_TAIL"
    ok "Patched linker config"
fi

# dpkg-deb — use stub on Windows
WINDOWS_MK="$THEOS/makefiles/platform/Windows.mk"
if ! grep -q 'DPKG_DEB' "$WINDOWS_MK" 2>/dev/null; then
    sed -i '/^_THEOS_PLATFORM_GET_LOGICAL_CORES/a\
_THEOS_PLATFORM_DPKG_DEB ?= dpkg-deb' "$WINDOWS_MK"
    ok "Patched dpkg-deb for Windows"
fi

ok "Theos patched"

# ── Step 8: Configure shell + Windows make wrapper ─────────────────
PROFILE="$HOME/.bashrc"
MARKER="# theos-windows"
if ! grep -q "$MARKER" "$PROFILE" 2>/dev/null; then
    cat >> "$PROFILE" << 'ENVEOF'

# theos-windows
export THEOS="$HOME/.theos/theos"
export PATH="$HOME/.theos/tools-bin:$THEOS/toolchain/windows/iphone/bin:$PATH"
export MSYS2_ARG_CONV_EXCL="-install_name;-dylib_install_name;/Library;/var;/usr"
ENVEOF
    ok "Added to ~/.bashrc"
fi

# Create make.bat wrapper so 'make' works from cmd.exe / PowerShell
GITBASH_WIN="$(cygpath -w "$(command -v bash)" 2>/dev/null || echo 'C:\Program Files\Git\bin\bash.exe')"
cat > "$PREFIX/make.bat" << BATEOF
@echo off
"$GITBASH_WIN" --login -c "cd '%CD:\=/%' && source ~/.bashrc 2>/dev/null && make %*"
BATEOF
ok "Created make.bat wrapper"

# Add to Windows PATH
info "Adding to Windows PATH..."
TOOLS_WIN="$(cygpath -w "$PREFIX")"
powershell.exe -Command "
\$p = [Environment]::GetEnvironmentVariable('PATH','User');
if (\$p -notlike '*$TOOLS_WIN*') {
    [Environment]::SetEnvironmentVariable('PATH', '$TOOLS_WIN;' + \$p, 'User')
}
[Environment]::SetEnvironmentVariable('THEOS', '$TOOLS_WIN\\theos', 'User')
" 2>/dev/null
ok "Windows PATH and THEOS configured"

# ── Done ───────────────────────────────────────────────────────────
echo ""
printf "${GREEN}============================================${NC}\n"
printf "${GREEN}  Installation complete!${NC}\n"
printf "${GREEN}============================================${NC}\n"
echo ""
echo "  Works in cmd.exe, PowerShell, and Git Bash."
echo "  Restart your terminal, then:"
echo ""
echo "  1. Create project:  \$THEOS/bin/nic.pl  (in Git Bash)"
echo ""
echo "  2. Build from ANY terminal:"
echo "     cd C:\\dev\\MyTweak"
echo "     make package"
echo ""
echo "  Installed to: ~/.theos"
echo "  .deb output:  ./packages/"
echo ""
echo "  [TheosWin extras] one command for multi-SDK / Swift / RootHide:"
echo "     bash setup-extras.sh --all        (or --sdks all / --swift / --roothide)"
echo ""
