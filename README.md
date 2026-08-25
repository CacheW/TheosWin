<div align="center">

# TheosWin

**Build iOS tweaks, dylibs, and apps natively on Windows.**
No WSL. No VM. No macOS.

An improved fork of [Leeksov/theos-windows](https://github.com/Leeksov/theos-windows) —
adding Swift, multi-SDK, RootHide, a pinned toolchain, and one-command setup.

</div>

---

## Why TheosWin

[Theos](https://github.com/theos/theos) is the standard build system for iOS
tweaks, but running it on Windows normally means WSL or a Mac. Leeksov solved the
native-Windows base (a real LLVM/clang cross-compiler + linker + SDK). **TheosWin
builds on that** and closes the remaining gaps so a Windows box is a first-class
iOS build environment — reproducible, multi-SDK, Swift-capable, and RootHide-ready.

## Highlights

| Capability | TheosWin |
|---|:---:|
| C / Objective-C / Objective-C++ → iOS | ✅ |
| C++ → iOS | ✅ |
| Logos `.x` / `.xm` | ✅ |
| **Swift** (logic via `@_cdecl`) → iOS | ✅ *(new)* |
| **Multi-SDK** — iOS 16.5 / 18.6 / 26.5, one command | ✅ *(new)* |
| **RootHide** jailbreak package scheme | ✅ *(new)* |
| **Pinned toolchain** for reproducible builds | ✅ *(new)* |
| One-command extras installer | ✅ *(new)* |
| Link · code-sign (ldid) · package `.deb`/`.ipa` | ✅ |

> Proven end-to-end: a Swift-powered app built entirely on Windows and run on real
> devices (iOS 17.6.1 iPad + iOS 27.0 iPhone). See [`examples/swift-demo/`](examples/swift-demo/).

---

## Quick start

**Prerequisites:** [Git for Windows](https://git-scm.com/download/win),
[Python 3](https://python.org) (`pip install zstandard`). A terminal (Git Bash,
PowerShell, or cmd).

### Install

Clone this repo and run the installer (works in Git Bash):

```bash
git clone https://github.com/CacheW/TheosWin.git
cd TheosWin
bash install.sh
```

Then add the extras you want (see below). Installs to `~/.theos`
(`%USERPROFILE%\.theos`). **Restart your terminal after installing.**

> The vanilla base can also be installed via the upstream one-liner
> (`install.ps1` / `install.sh` from Leeksov) — TheosWin's extras layer on top.

### Extras — one command

```bash
bash setup-extras.sh --all          # SDKs + Swift toolchain + RootHide
# …or pick pieces:
bash setup-extras.sh --sdks all     # iOS 16.5 + 18.6 + 26.5
bash setup-extras.sh --swift        # swift.org toolchain (Swift logic → iOS)
bash setup-extras.sh --roothide     # RootHide package scheme
bash setup-extras.sh --toolchain    # pinned LLVM 19 (byte-identical, reproducible)
```

---

## Usage

### Create and build a tweak

```bash
$THEOS/bin/nic.pl        # scaffold a new project
make                     # compile
make package             # compile + .deb (→ ./packages/)
make clean
```

Minimal `Makefile`:

```makefile
ARCHS = arm64
TARGET = iphone:clang:16.5:14.5      # SDK : min-deployment

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MyTweak
MyTweak_FILES = Tweak.x
MyTweak_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
```

### Target a specific SDK

Install the SDKs, then choose per project via `TARGET`:

```bash
bash tools/install-sdks.sh all      # or: 18.6 26.5
```
```makefile
TARGET = iphone:clang:18.6:14.5     # 16.5 is the safe default
```

### RootHide tweak

```bash
bash tools/add-roothide.sh
make THEOS_PACKAGE_SCHEME=roothide
```

### Swift (logic) → iOS

Write pure Swift logic, expose it with `@_cdecl`, call it from ObjC:

```swift
// logic.swift
@_cdecl("aim_smooth")
public func aim_smooth(_ cur: Float, _ tgt: Float, _ speed: Float) -> Float {
    cur + (tgt - cur) * min(max(speed, 0), 1)
}
```
```bash
tools/swiftc-ios -O -emit-object logic.swift -o logic.o   # → arm64-ios object
```

Full recipe, working example, and the honest limits: [`docs/Swift.md`](docs/Swift.md).

---

## Capabilities & honest limits

**Swift** cross-compiles for iOS on Windows — the full language and standard
library (`String`, collections, generics, protocols, error handling, **`async`/`await`**,
**`Regex`**). The working pattern is **Swift logic + `@_cdecl`, with UI/frameworks in
ObjC**. `import UIKit` / `import Foundation` **from Swift** is not achievable on
Windows — those overlays require Apple's own swiftc (Xcode/macOS only). Details and
the full test matrix are in [`docs/Swift.md`](docs/Swift.md).

**What no tool can port from Xcode to Windows** (all closed, macOS-only): the iOS
Simulator, Apple's swiftc, and `actool` / `ibtool` / `metal`. TheosWin covers the
**build → link → sign → package** pipeline for C/ObjC/C++ and Swift logic — 100% of
what tweaks and code-driven apps need.

**Toolchain:** one Windows-host iOS toolchain exists publicly (LLVM 19). A second /
custom clang would require a from-source build — analysis in
[`docs/DarkClang.md`](docs/DarkClang.md).

---

## Repository layout

```
install.sh / .ps1 / .bat   base installer (native Windows Theos)
setup-extras.sh            one-command extras (SDKs / Swift / RootHide / toolchain)
tools/
  install-sdks.sh          install pre-patched iOS SDKs from the sdks-v1 release
  install-toolchain.sh     install the pinned LLVM 19 (reproducibility)
  add-sdk.py               materialize any mirror iOS SDK for Windows
  add-roothide.sh          add the RootHide package scheme
  swiftc-ios               Swift → arm64-ios cross-compile wrapper
roothide-support/          RootHide package-scheme module
examples/swift-demo/       ObjC UI + Swift logic → installable .ipa
docs/Swift.md              Swift on iOS: recipe, capabilities, limits
docs/DarkClang.md          custom obfuscating clang: analysis + recipe
THEOSWIN.md                improvements-over-upstream index
```

**Releases:** `sdks-v1` (iOS 16.5 + 18.6 + 26.5, Windows-patched) ·
`toolchain-v1` (pinned LLVM 19).

---

## What gets installed

| Component | Size | Source |
|---|---|---|
| Clang / LLD cross-compiler (LLVM 19) | ~150 MB | [L1ghtmann/llvm-project](https://github.com/L1ghtmann/llvm-project) (Apple fork) |
| Theos | ~50 MB | [theos/theos](https://github.com/theos/theos) |
| iOS SDK(s) | ~70 MB ea. | Windows-patched, hosted on this repo's `sdks-v1` |
| ldid (code signing) | ~1 MB | [ProcursusTeam/ldid](https://github.com/ProcursusTeam/ldid) |
| Strawberry Perl (Logos `.x`) | ~290 MB | [strawberryperl.com](https://strawberryperl.com) |
| Swift toolchain *(optional)* | ~540 MB | [swift.org](https://www.swift.org/install/windows/) |

## Supported file types

| Extension | Type | Status |
|---|---|:---:|
| `.m` / `.mm` | Objective-C / Objective-C++ | ✅ |
| `.c` / `.cpp` | C / C++ | ✅ |
| `.x` / `.xm` | Logos (ObjC / ObjC++) | ✅ |
| `.swift` | Swift (logic via `@_cdecl`; frameworks in ObjC) | ✅ *(see [docs/Swift.md](docs/Swift.md))* |

## Notes

- **No spaces in the project path** (Theos limitation, all platforms). Use `C:\dev\MyTweak`.
- Code signing is disabled by default — sign on-device, via ldid, or let ESign re-sign.
- **CydiaSubstrate** is a link-time stub; the real library loads on-device.
- Uses MSYS2 make (not MSVC make) — required for Theos's bash-based makefiles.

## Troubleshooting

| Problem | Fix |
|---|---|
| `platform does not define a default target` | Use MSYS2 make: `make --version` must say `x86_64-pc-msys` |
| `stdarg.h not found` | Missing clang headers — re-run the installer |
| Logos `.x` fails with `Can't locate…` | Perl issue: `perl -e "use Locale::Maketext::Simple"` |
| `does not support linking for platform iOS` | lld not patched — re-install the toolchain |
| Path errors with `C:/Program Files/…` | `export MSYS2_ARG_CONV_EXCL="-install_name;-dylib_install_name;/Library"` |

## How it works

The installer sets up a pre-built LLVM/Clang cross-compiler (Apple fork with iOS
support), patches lld's Mach-O linker to allow iOS linking on Windows, configures
Theos with Windows platform detection, and stubs Unix-only tools. Key patches:

- **lld** — removes Apple's "platform not supported" check that blocks iOS linking off-macOS.
- **ld wrapper** — maps `-iphoneos_version_min` → `-platform_version ios` (lld ld64 flavor).
- **Theos makefiles** — MINGW/MSYS → Windows platform mapping + `ld64.lld` linker path.

## Credits

Built on the work of [Theos](https://github.com/theos/theos),
[Leeksov/theos-windows](https://github.com/Leeksov/theos-windows),
[L1ghtmann/llvm-project](https://github.com/L1ghtmann/llvm-project),
[roothide/theos](https://github.com/roothide/theos),
[xybp888/iOS-SDKs](https://github.com/xybp888/iOS-SDKs),
[ProcursusTeam/ldid](https://github.com/ProcursusTeam/ldid), and
[Strawberry Perl](https://strawberryperl.com/).

## License

Installer scripts: MIT. Bundled components keep their own licenses
(LLVM: Apache-2.0 · Theos: GPLv3 · Perl: Artistic/GPL).
