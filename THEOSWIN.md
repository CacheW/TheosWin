# TheosWin — improvements over upstream theos-windows

A private, improved fork of [Leeksov/theos-windows](https://github.com/Leeksov/theos-windows).
The base installer is unchanged (tag `upstream-baseline` for diffing); everything
below is additive.

## What's added

### 1. Swift on iOS — `.swift` cross-compiles (upstream marks it ❌)
Proven on real devices (iOS 17.6.1 + iOS 27.0). Pure Swift + `@_cdecl` called from
ObjC works; `import Foundation/UIKit` from Swift is blocked by Apple's overlay ABI.
- Recipe + limits: [`docs/Swift.md`](docs/Swift.md)
- Wrapper: [`tools/swiftc-ios`](tools/swiftc-ios)
- Working example → installable `.ipa`: [`examples/swift-demo/`](examples/swift-demo/)

### 2. Multi-SDK (incl. iOS 18.6 and 26.5)
Upstream ships one SDK (16.5). `tools/add-sdk.py` materializes any community-mirror
iOS SDK for Windows (resolves framework symlinks via git metadata). Pre-patched
SDKs are on the **`sdks-v1`** release:
- `iPhoneOS26.5-windows.sdk.tar.gz`, `iPhoneOS18.6-windows.sdk.tar.gz`
- Install: drop into `$THEOS/sdks/`, then `TARGET = iphone:clang:26.5:14.5` (etc.)
- 16.5 stays the default; the newer ones are opt-in per project.

### 3. DarkClang analysis (custom obfuscating clang)
Honest write-up of what a custom LLVM fork can/can't do (anti-theft yes,
anti-detection no) + a from-source build recipe: [`docs/DarkClang.md`](docs/DarkClang.md).

## Clang reality (native Windows)
Only **one** Windows-host iOS toolchain exists publicly (Leeksov's LLVM 19).
L1ghtmann's other releases are Linux/macOS. A second Windows clang would need a
from-source build (see `docs/DarkClang.md`). So TheosWin stays on LLVM 19.
