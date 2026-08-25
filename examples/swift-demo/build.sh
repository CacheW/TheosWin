#!/usr/bin/env bash
# build.sh — reproduce VantaSwiftDemo.ipa entirely on native Windows.
# Proves Swift runs on iOS (tested on iOS 17.6.1 + 27.0): ObjC UI + Swift @_cdecl logic.
#
#   Swift logic ─swiftc(Win)─► arm64-ios .o ┐
#   ObjC UI     ─clang(theos)─► arm64-ios .o ┼─► link ─► app ─► /usr/lib/swift/libswiftCore.dylib
#                                            ┘
# Requires: Theos-for-Windows installed + a swift.org Windows toolchain (see docs/Swift.md).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

: "${THEOS:=$HOME/.theos/theos}"
SDK="${SDK:-$THEOS/sdks/iPhoneOS16.5.sdk}"
TCB="$THEOS/toolchain/windows/iphone/bin"
NAME="VantaSwift"

echo "[1/4] Swift @_cdecl -> arm64-ios object"
SDK="$SDK" IOS_TARGET="arm64-apple-ios14.5" \
  "$(dirname "$HERE")/../tools/swiftc-ios" -O -emit-object swift_export.swift -o swift_export.o

echo "[2/4] ObjC (UIKit) -> arm64-ios object"
"$TCB/clang.exe" -target arm64-apple-ios14.5 -isysroot "$SDK" -fobjc-arc -O2 -c main.m -o main.o

echo "[3/4] link ObjC + Swift -> app executable"
"$TCB/clang.exe" -target arm64-apple-ios14.5 -isysroot "$SDK" \
  main.o swift_export.o \
  -framework UIKit -framework Foundation \
  -L"$SDK/usr/lib/swift" -lswiftCore \
  -Xlinker -rpath -Xlinker /usr/lib/swift \
  -o "$NAME"

echo "[4/4] package .ipa (ldid fake-sign; ESign re-signs on install)"
rm -rf Payload "$NAME.app"
mkdir -p "Payload/$NAME.app"
cp "$NAME" Info.plist "Payload/$NAME.app/"
"$HOME/.theos/tools-bin/ldid" -S "Payload/$NAME.app/$NAME"
rm -f "${NAME}Demo.ipa"
zip -r -q "${NAME}Demo.ipa" Payload
rm -rf Payload main.o swift_export.o "$NAME"
echo "DONE -> $HERE/${NAME}Demo.ipa   (sideload with ESign, launch, expect fib(20)=6765 / add(40,2)=42)"
