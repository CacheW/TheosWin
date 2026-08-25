# Swift on iOS from native Windows — WORKS (with one honest limit)

Theos-for-Windows marks `.swift` as **❌ No cross-compiler**. That's not a hard
block — it just means nobody wired a Windows `swiftc` for iOS. This repo does.

**Proven on real devices (2026-08-24): iOS 17.6.1 (iPad) + iOS 27.0 (iPhone 17).**
A Swift function compiled entirely on Windows ran on both — `fib(20)=6765`,
`add(40,2)=42` (see `examples/swift-demo/`).

## What works vs. what doesn't

| | Status |
|---|---|
| Pure Swift (stdlib only) → arm64-iOS object | ✅ compiles + runs on device |
| Swift `@_cdecl` C-ABI functions called from ObjC/C | ✅ the usable pattern |
| Link ObjC + Swift → app/dylib, Swift runtime from `/usr/lib/swift` | ✅ |
| `import Foundation` / `import UIKit` **from Swift** | ❌ blocked |

**Why the `import` limit:** the iOS SDK ships each framework's Swift overlay as a
textual `.swiftinterface` produced by **Apple's** swiftc (a private fork). A
`swift.org` Windows swiftc rebuilds those interfaces and hits ABI/content
mismatches (e.g. `no type named 'DispatchIO' in module 'Dispatch'` when Foundation
pulls in Dispatch). This needs Apple's exact swiftc, which doesn't exist for
Windows. It's an Apple-ABI wall, not a missing flag.

**The practical pattern:** write framework-touching code (UIKit/Foundation) in
**ObjC/C++**, write pure logic in **Swift**, bridge with `@_cdecl`:

```swift
@_cdecl("myLogic")                       // exports a C symbol
public func myLogic(_ n: Int32) -> Int32 { /* pure Swift, no imports */ }
```
```objc
extern int myLogic(int n);               // ObjC calls it like any C function
```

## Setup (one time)

1. Install Theos-for-Windows (this repo's `install.sh`).
2. Install a swift.org **Windows** toolchain (has `swiftc.exe`):
   `https://www.swift.org/install/windows/` (Swift 6.1.2 was used here).
   It installs to `~/AppData/Local/Programs/Swift/{Toolchains,Runtimes}`.
   Needs VS 2022 BuildTools (the MSVC runtime) — which Theos users usually have.
3. Add at least one patched iOS SDK to `$THEOS/sdks/` (see `tools/add-sdk.py`).

## Compile Swift for iOS

Use the wrapper `tools/swiftc-ios` (encapsulates the working invocation):

```bash
SDK="$THEOS/sdks/iPhoneOS16.5.sdk" IOS_TARGET="arm64-apple-ios14.5" \
  tools/swiftc-ios -O -emit-object mylogic.swift -o mylogic.o
```

The wrapper's key discovered flags:
- runtime DLLs (`Runtimes/*/usr/bin`) **must** be on `PATH` or swiftc.exe dies with
  `0xC0000135` (DLL not found).
- `-target arm64-apple-ios<min>` + `-sdk <patched iOS sdk>` (Windows path).
- `-runtime-compatibility-version none` + `-Xfrontend -disable-autolinking-runtime-compatibility`
  → stops swiftc auto-linking the Apple back-deploy shims
  (`swiftCompatibilityConcurrency`, `swiftCompatibility56`, …) which don't exist
  here and otherwise fail the link.

## Link + package

Link with Theos's clang against the SDK's Swift runtime stub; the runtime itself
lives on-device (iOS 12.2+):

```bash
clang -target arm64-apple-ios14.5 -isysroot "$SDK" \
  main.o mylogic.o -framework UIKit -framework Foundation \
  -L"$SDK/usr/lib/swift" -lswiftCore \
  -Xlinker -rpath -Xlinker /usr/lib/swift -o MyApp
```

Full reproducible example: `examples/swift-demo/build.sh` → `VantaSwiftDemo.ipa`.

## Adding `.swift` to a Theos project

Theos's own rules don't invoke swiftc on Windows, so the non-invasive way (survives
Theos updates) is to compile the `.swift` via `tools/swiftc-ios` and feed the `.o`
to your project's `*_FILES`/link. See `examples/swift-demo/build.sh` for the exact
steps a Makefile rule would run.
