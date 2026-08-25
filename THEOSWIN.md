# TheosWin — improvements over upstream theos-windows

A private, improved fork of [Leeksov/theos-windows](https://github.com/Leeksov/theos-windows).
The base installer is unchanged (tag `upstream-baseline` for diffing); everything
below is additive.

## One-command extras

After the base `install.sh`, add everything with:
```bash
bash setup-extras.sh --all          # multi-SDK + Swift toolchain + RootHide
bash setup-extras.sh --sdks all     # or pick pieces: --sdks 18.6,26.5 --roothide --swift
```

## What's added

### 1. Swift on iOS — `.swift` cross-compiles (upstream marks it ❌)
Proven on real devices (iOS 17.6.1 + iOS 27.0). **Pure Swift + `@_cdecl` called from
ObjC works and runs on device.** Full `import Foundation/UIKit` from Swift is **not
achievable** on native Windows — exhaustively tested: swift.org swiftc 6.1.2 & 6.3.3
vs SDK 16.5 & 18.6 all fail (overlay ABI on old SDKs; "error extracting version" on
Apple's core `Swift.swiftinterface` on matching SDKs), and even the ObjC-bridging-header
workaround fails (UIKit clang module OOM/blocked). It needs Apple's own swiftc
(Xcode/macOS). Ceiling = Swift logic + ObjC frameworks via `@_cdecl`.
- Recipe + full test matrix: [`docs/Swift.md`](docs/Swift.md)
- Wrapper: [`tools/swiftc-ios`](tools/swiftc-ios)
- Working example → installable `.ipa`: [`examples/swift-demo/`](examples/swift-demo/)

### 2. RootHide jailbreak package scheme
Adds the `roothide` package scheme (from [roothide/theos](https://github.com/roothide/theos))
so you can build tweaks for RootHide-jailbroken devices. Ported as an additive
overlay that does **not** disturb the Windows patches (roothide only adds
`vendor/mod/roothide` + a 3-line `rules.mk` change).
- Apply: [`tools/add-roothide.sh`](tools/add-roothide.sh) → then `make THEOS_PACKAGE_SCHEME=roothide`
- Scheme files: [`roothide-support/`](roothide-support/)
- Windows caveat: the scheme (install_name `@loader_path/.jbroot…`, arm64e) builds
  fine; final `.deb` packaging has the usual Theos-on-Windows dpkg-deb-stub limit.
  Needs a RootHide device to verify end-to-end.

### 3. Multi-SDK (16.5 + 18.6 + 26.5), self-contained
Upstream ships one SDK (16.5). All three are now pre-patched (Windows framework
symlinks materialized) and hosted on TheosWin's own **`sdks-v1`** release, so the
setup no longer depends on any other repo.
- **One-command install:** [`tools/install-sdks.sh`](tools/install-sdks.sh)
  `[16.5|18.6|26.5|all]` → downloads from `sdks-v1` into `$THEOS/sdks/`.
- Make another version yourself from any mirror: [`tools/add-sdk.py`](tools/add-sdk.py)
  (resolves framework symlinks via git metadata).
- Select per project: `TARGET = iphone:clang:26.5:14.5` (etc.). 16.5 is the safe
  default; newer ones are opt-in per project.

### 4. DarkClang analysis (custom obfuscating clang)
Honest write-up of what a custom LLVM fork can/can't do (anti-theft yes,
anti-detection no) + a from-source build recipe: [`docs/DarkClang.md`](docs/DarkClang.md).

## Clang reality (native Windows)
Only **one** Windows-host iOS toolchain exists publicly (Leeksov's LLVM 19).
L1ghtmann's other releases are Linux/macOS. A second Windows clang would need a
from-source build (see `docs/DarkClang.md`). So TheosWin stays on LLVM 19.
