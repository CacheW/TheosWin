#!/usr/bin/env python3
"""
add-sdk.py — download an iPhoneOS SDK from a community mirror and materialize it
for native Windows Theos (which can't use the framework symlinks), then install it
into $THEOS/sdks/ and optionally emit a .tar.gz for hosting.

Why: real Apple SDKs use symlinks inside every .framework
    Foo.framework/Foo            -> Versions/Current/Foo
    Foo.framework/Headers        -> Versions/Current/Headers
    Foo.framework/Versions/Current -> A
Windows/MSYS2 git can't follow those (they land as symlink-as-text or dangle), so
Theos fails to find headers/tbds. This script reads the symlinks from GIT METADATA
(index mode 120000 — reliable no matter how the working tree materialized them),
resolves each chain to its real target, and writes a fully materialized tree.

Usage:
    python add-sdk.py iPhoneOS26.5.sdk [--repo <git-url>] [--tar OUT.tar.gz] [--keep-temp]

Defaults: mirror = xybp888/iOS-SDKs ; install into $THEOS/sdks/<SDK>.
"""
import os, sys, subprocess, shutil, tempfile, argparse, tarfile

def run(cmd, cwd=None):
    subprocess.check_call(cmd, cwd=cwd)
def out(cmd, cwd=None):
    return subprocess.check_output(cmd, cwd=cwd, text=True, errors="replace")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sdk", help="e.g. iPhoneOS26.5.sdk")
    ap.add_argument("--repo", default="https://github.com/xybp888/iOS-SDKs.git")
    ap.add_argument("--tar", default=None, help="also write a .tar.gz here (for hosting)")
    ap.add_argument("--theos", default=os.environ.get("THEOS", os.path.expanduser("~/.theos/theos")))
    ap.add_argument("--keep-temp", action="store_true")
    a = ap.parse_args()
    SDK = a.sdk.rstrip("/")

    tmp = tempfile.mkdtemp(prefix="addsdk_")
    repo = os.path.join(tmp, "repo")
    print(f"[1/5] blobless sparse clone of {SDK} from {a.repo} ...", flush=True)
    run(["git", "clone", "--no-checkout", "--filter=blob:none", "--depth", "1", a.repo, repo])
    run(["git", "-C", repo, "sparse-checkout", "set", "--no-cone", SDK])
    run(["git", "-C", repo, "checkout"])
    srcroot = os.path.join(repo, SDK)
    if not os.path.isdir(srcroot):
        sys.exit(f"ERROR: {SDK} not found in the mirror repo")

    print("[2/5] reading symlinks from git metadata (mode 120000) ...", flush=True)
    symlinks = {}   # relpath-from-SDK -> target string
    for line in out(["git", "-C", repo, "ls-files", "-s", "--", SDK]).splitlines():
        meta, path = line.split("\t", 1)
        fields = meta.split()
        if fields[0] == "120000":
            target = out(["git", "-C", repo, "cat-file", "-p", fields[1]]).strip()
            rel = os.path.relpath(path, SDK).replace("\\", "/")
            symlinks[rel] = target
    print(f"      {len(symlinks)} symlinks to resolve", flush=True)

    # Resolve a rel path left-to-right, substituting any symlink component (chains + prefixes).
    def realpath(rel, depth=0):
        if depth > 80:
            return None
        parts = rel.split("/")
        acc = []
        for i, p in enumerate(parts):
            cand = "/".join(acc + [p])
            if cand in symlinks:
                base = "/".join(acc)
                newp = os.path.normpath(((base + "/") if base else "") + symlinks[cand]).replace("\\", "/")
                rest = parts[i + 1:]
                return realpath(newp + (("/" + "/".join(rest)) if rest else ""), depth + 1)
            acc.append(p)
        return "/".join(acc)

    dest = os.path.join(a.theos, "sdks", SDK)
    if os.path.exists(dest):
        shutil.rmtree(dest)

    print("[3/5] copying real files ...", flush=True)
    for root, dirs, files in os.walk(srcroot):
        rel = os.path.relpath(root, srcroot).replace("\\", "/")
        for f in files:
            r = f if rel == "." else rel + "/" + f
            if r in symlinks:
                continue                      # handled in step 4
            d = os.path.join(dest, r.replace("/", os.sep))
            os.makedirs(os.path.dirname(d), exist_ok=True)
            shutil.copy2(os.path.join(root, f), d)

    print("[4/5] materializing symlinks as real files/dirs ...", flush=True)
    broken = 0
    for rel in symlinks:
        real = realpath(rel)
        src_real = os.path.join(srcroot, real.replace("/", os.sep)) if real else None
        d = os.path.join(dest, rel.replace("/", os.sep))
        os.makedirs(os.path.dirname(d), exist_ok=True)
        if src_real and os.path.isdir(src_real):
            if os.path.exists(d):
                shutil.rmtree(d)
            shutil.copytree(src_real, d)
        elif src_real and os.path.isfile(src_real):
            shutil.copy2(src_real, d)
        else:
            broken += 1                       # dangles outside the SDK — safe to skip
    if broken:
        print(f"      ({broken} symlinks pointed outside the SDK — skipped, normal)", flush=True)

    ok = os.path.isfile(os.path.join(dest, "SDKSettings.plist"))
    nfw = sum(1 for _r, ds, _f in os.walk(dest) for _d in ds if _d.endswith(".framework"))
    print(f"[5/5] installed -> {dest}", flush=True)
    print(f"      SDKSettings.plist: {'OK' if ok else 'MISSING'} | frameworks: {nfw}", flush=True)
    if not ok:
        sys.exit("ERROR: SDKSettings.plist missing — SDK looks incomplete")

    if a.tar:
        print(f"      packing {a.tar} ...", flush=True)
        with tarfile.open(a.tar, "w:gz") as t:
            t.add(dest, arcname=SDK)
        print(f"      tar: {a.tar} ({os.path.getsize(a.tar)//1048576} MB)", flush=True)

    if not a.keep_temp:
        shutil.rmtree(tmp, ignore_errors=True)
    print("DONE", flush=True)

if __name__ == "__main__":
    main()
