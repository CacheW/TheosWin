# Theos for Windows

Build iOS tweaks natively on Windows. No WSL, no VM, no macOS required.

---

## 🛠️ TheosWin — this fork's additions (see [`THEOSWIN.md`](THEOSWIN.md))

A private, improved fork of [Leeksov/theos-windows](https://github.com/Leeksov/theos-windows)
(base installer unchanged; tag `upstream-baseline` for diffing).

- **Swift on iOS — `.swift` cross-compiles** (upstream marks it ❌). Proven on real
  devices (iOS 17.6.1 + 27.0). **Pure Swift + `@_cdecl` called from ObjC works and
  runs on device.** Full `import UIKit`/`import Foundation` from Swift is **NOT
  achievable** on native Windows — it needs Apple's own swiftc (Xcode/macOS); a
  swift.org Windows swiftc can't consume Apple's SDK Swift interfaces (tested 6.1.2
  & 6.3.3 vs SDK 16.5 & 18.6 — all fail at the Apple-vs-swift.org version wall).
  Full write-up + recipe: [`docs/Swift.md`](docs/Swift.md), wrapper
  [`tools/swiftc-ios`](tools/swiftc-ios), working example
  [`examples/swift-demo/`](examples/swift-demo/).
- **RootHide jailbreak scheme** — build tweaks for RootHide devices:
  [`tools/add-roothide.sh`](tools/add-roothide.sh) → `make THEOS_PACKAGE_SCHEME=roothide`.
  Additive port of [roothide/theos](https://github.com/roothide/theos) that keeps the
  Windows patches intact.
- **Multi-SDK** — `tools/add-sdk.py` materializes any community-mirror iOS SDK for
  Windows (resolves framework symlinks via git metadata). Pre-patched **iOS 18.6 +
  26.5** on the [`sdks-v1`](../../releases/tag/sdks-v1) release. Drop into
  `$THEOS/sdks/`, target with `TARGET = iphone:clang:26.5:14.5`. 16.5 stays default.
- **DarkClang** — honest analysis of a custom obfuscating clang (anti-theft yes,
  anti-detection no) + from-source recipe: [`docs/DarkClang.md`](docs/DarkClang.md).
- **Clang reality:** only one Windows-host iOS toolchain exists (LLVM 19); a second
  would need a from-source build. TheosWin stays on LLVM 19.

> **What can't be ported from Xcode (fundamental):** the iOS Simulator, Apple's
> swiftc, `actool`/`ibtool`/`metal` — all closed and macOS-only. TheosWin covers
> the **build → link → sign → package** pipeline for C/ObjC/C++ (and Swift logic),
> which is 100% of what tweaks and code-driven apps need.

---

## Install

Everything downloads automatically from GitHub. Nothing to build.

### Option 1: PowerShell (recommended, auto-installs Git if needed)

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/Leeksov/theos-windows/master/install.ps1 -OutFile i.ps1; .\i.ps1; del i.ps1"
```

### Option 2: Git Bash (if you already have Git)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Leeksov/theos-windows/master/install.sh)
```

### Prerequisites
- [Python 3](https://python.org) + `pip install zstandard`
- Git for Windows — installed automatically if missing

Installs to `~/.theos` (`%USERPROFILE%\.theos`). Restart terminal after install.

## Usage

### Create a tweak

```bash
$THEOS/bin/nic.pl
```

### Makefile

```makefile
ARCHS = arm64
TARGET = iphone:16.5:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MyTweak
MyTweak_FILES = Tweak.x
MyTweak_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
```

### Build

```bash
make              # compile only
make package      # compile + .deb
make clean        # clean
```

`.deb` goes to `./packages/`.

## What Gets Installed

| Component | Size | Source |
|-----------|------|--------|
| Clang/LLD cross-compiler | ~150 MB | Pre-built from [L1ghtmann/llvm-project](https://github.com/L1ghtmann/llvm-project) (Apple fork) |
| GNU Make (MSYS2) | ~1 MB | Pre-built |
| ldid (code signing) | ~1 MB | Built from [ProcursusTeam/ldid](https://github.com/ProcursusTeam/ldid) |
| Theos | ~50 MB | Cloned from [theos/theos](https://github.com/theos/theos) |
| iOS SDK | ~70 MB | Downloaded by Theos |
| Strawberry Perl | ~290 MB | Downloaded from [strawberryperl.com](https://strawberryperl.com) (needed for Logos `.x` files) |
| Tool stubs | ~5 KB | fakeroot, dpkg-deb, rsync replacements |

## Supported File Types

| Extension | Type | Status |
|-----------|------|--------|
| `.m` | Objective-C | ✅ |
| `.mm` | Objective-C++ | ✅ |
| `.c` / `.cpp` | C / C++ | ✅ |
| `.x` | Logos (ObjC) | ✅ |
| `.xm` | Logos (ObjC++) | ✅ |
| `.swift` | Swift | ❌ No cross-compiler |

## Important Notes

- **No spaces in project path.** Use paths like `C:\dev\tweaks\MyTweak`
- **Code signing** is disabled by default. Sign on-device or use ldid separately
- **CydiaSubstrate** is a stub for linking — the real lib loads on-device
- Uses MSYS2 make (not MSVC make) — required for bash-based Theos makefiles

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `platform does not define a default target` | Use MSYS2 make: `make --version` → must say `x86_64-pc-msys` |
| `stdarg.h not found` | Missing clang headers. Re-run installer |
| Logos `.x` fails with `Can't locate...` | Perl issue. Run: `perl -e "use Locale::Maketext::Simple"` |
| `does not support linking for platform iOS` | lld not patched. Re-download toolchain |
| Path errors with `C:/Program Files/...` | Set `export MSYS2_ARG_CONV_EXCL="-install_name;-dylib_install_name;/Library"` |

## How It Works

The installer downloads a pre-built LLVM/Clang cross-compiler (Apple fork with iOS support), patches lld's Mach-O linker to allow iOS linking on Windows, sets up Theos with Windows platform detection, and provides stub replacements for Unix-only tools.

Key patches:
- **lld**: Removes Apple's "platform not supported" check in `InputFiles.cpp` that blocks iOS linking on non-macOS
- **ld wrapper**: Translates `-iphoneos_version_min` to `-platform_version ios` (lld ld64 flavor requirement)
- **Theos makefiles**: MINGW/MSYS → Windows platform mapping, ld64.lld linker path

## Credits

- [Theos](https://github.com/theos/theos)
- [L1ghtmann/llvm-project](https://github.com/L1ghtmann/llvm-project)
- [ProcursusTeam/ldid](https://github.com/ProcursusTeam/ldid)
- [Strawberry Perl](https://strawberryperl.com/)

## License

MIT (installer scripts). Components have their own licenses (LLVM: Apache 2.0, Theos: GPLv3, Perl: Artistic/GPL).
