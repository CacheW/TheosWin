# DarkClang — honest technical analysis

> Idea: a custom clang fork (based on L1ghtmann's LLVM 19) with heavy improvements
> for hack/external-app devs — "un clang fantasma" that no anticheat, no game, and
> not even iOS itself can detect, to shield against detection.

This document answers, honestly, **what a custom compiler can and cannot do** for
that goal — because getting this wrong wastes weeks (we already lived it: see the
Arkari/OLLVM saga in the project memory `string-obfuscation.md`).

## Short answer

- **A custom clang is REAL and buildable.** It's exactly what OLLVM / Hikari /
  Arkari are: a fork of LLVM + custom passes. So "DarkClang" as a *tool* is 100%
  feasible.
- **But a compiler CANNOT make running code "undetectable" to an anticheat or to
  iOS.** That part is a misconception about where detection happens. No codegen
  trick hides a process from something that reads process memory or the loaded
  image list at runtime. A "ghost clang nothing detects" is not achievable.

## What a custom clang genuinely CAN do

1. **Anti-reverse-engineering (anti-THEFT).** Control-flow flattening, bogus
   control flow, string/constant encryption, indirect calls. Makes a human with
   IDA/Ghidra take much longer to understand your dylib. This protects your IP
   from being *stolen/copied* — it does nothing about *ban detection*.
2. **Build diversification.** Randomize codegen so every build has different byte
   patterns → defeats naive *signature/hash* detection ("this exact dylib hash =
   known cheat"). Useful only against signature-based scanners.

## What it CANNOT do (the core misconception)

Detection of an injected iOS menu is **runtime + behavioral + server-side**, none
of which a compiler touches:

- The dylib is still in the process → visible via `_dyld_image_count` / the loaded
  image list. Compiler can't hide that (it's the iOS runtime, not codegen).
- Reads/writes to game memory (ESP/aim) are **behavior** an anticheat observes at
  runtime. Codegen can obfuscate *how* the read is written, not *that* it happens.
- The bans this project actually gets are **report-driven / App-Attest / memory-
  tamper tiers** (see memory `anogs-report-ban`, `ios26-certspoof-fix`) — all
  server-side or runtime. A compiler emits nothing that changes them.
- iOS **must** load + codesign-validate the binary in cleartext (AMFI). There is
  no "ghost" execution mode; unsigned/hidden code doesn't run on non-JB iOS.
- **Anti-debug inserted by a compiler would HURT**: anogs flags ptrace/anti-attach
  as tampering → *ban risk* (memory `string-obfuscation`, `anogs-ios-guide`).

## We already tried this (don't re-learn it the hard way)

The project built a full OLLVM clang (KomiMoe/Arkari, LLVM 19, Windows, from
source) and used it via `OLLVM_CC`. Outcome (memory `string-obfuscation.md`):
- Address-encryption passes (indbr/icall/indgv) **crashed the iOS loader**
  ("large offset not support") — iOS dylibs are PIC; encrypting addresses breaks
  the fixup model.
- Data passes (string/const enc) **broke Streamer Mode**.
- Net anti-ban benefit ≈ **zero** (bans are runtime/server-side). The only real
  win was anti-RE (theft), which the manual `OBFS` layer already covers.
- It was **abandoned 2026-06-23** in favor of manual OBFS + CFObf + decoys +
  symbol strip.

## So: is DarkClang worth building?

- **For anti-DETECTION / anti-ban: NO.** No compiler delivers that. It's the wrong
  layer. Anti-ban lives in runtime egress scrubbing, App-Attest handling, cert
  spoofing, non-ISH hooks — code, not codegen.
- **For anti-THEFT (harder to reverse/copy): MAYBE.** A custom clang can flatten
  *everything* (not just the hand-annotated cold functions we do now) and encrypt
  more data. But you already hit the costs: iOS-loader fragility, Streamer break,
  FPS hits on per-frame code. Worth it only if theft-protection becomes the top
  priority and you accept re-fighting those issues.

## If you still want to build it — the realistic recipe

DarkClang = fork `L1ghtmann/llvm-project` (LLVM 19, matches Theos), add/enable
obfuscation passes (Arkari's `-irobf-*` lineage, or write your own), build a
**Windows-host, iOS-target** toolchain from source:

1. Prereqs (Windows): VS 2022 BuildTools (C++), CMake, Ninja.
2. `cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_PROJECTS="clang;lld"
   -DLLVM_ENABLE_DIA_SDK=OFF -DLLVM_TARGETS_TO_BUILD="AArch64;X86" ...\llvm`
   then `ninja` (~1h, ~30–50 GB scratch). Output `bin/clang.exe`, `ld64.lld.exe`.
3. Use via Theos by pointing `TARGET_CC`/`TARGET_CXX` at that `bin/` + a linker
   `-B` path (this is exactly the mechanism the removed OLLVM Makefile block used).
4. iOS-safe pass set only: **flatten (`-irobf-cff`) + data enc**, NEVER address
   encryption (crashes the loader). Flatten per-COLD-function (FPS on per-frame).

That gives a stronger anti-THEFT clang. Name it DarkClang, keep it in this repo's
releases. **But keep expectations correct: it hardens against code theft, not
against anticheat/iOS detection.**
