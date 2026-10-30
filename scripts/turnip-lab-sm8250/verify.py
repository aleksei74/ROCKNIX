#!/usr/bin/env python3
"""Validate an isolated Linux ARM64 Turnip lab artifact for SM8250."""

import argparse
import hashlib
import json
import os
import re
import subprocess
import tarfile
from pathlib import Path

INSTALL_ROOT = Path("/storage/.config/turnip-test")
VARIANTS = ("baseline", "sysmem", "autotune")
FORBIDDEN = {
    "libhardware.so", "liblog.so", "libnativewindow.so",
    "libsync.so", "libc++_shared.so",
}


def check(condition, message):
    if not condition:
        raise ValueError(message)


def command(*args):
    return subprocess.run(
        args, capture_output=True, text=True, check=True
    ).stdout


def file_sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_elf(lib):
    check(lib.is_file() and lib.stat().st_size > 100000,
          f"Missing or too small Linux driver: {lib}")
    header = command("aarch64-linux-gnu-readelf", "-h", str(lib))
    check("ELF64" in header and "AArch64" in header,
          "Driver is not a 64-bit AArch64 ELF")
    dynamic = command("aarch64-linux-gnu-readelf", "-d", str(lib))
    needed = set(re.findall(r"Shared library: \[(.*?)\]", dynamic))
    check("libc.so.6" in needed,
          "Driver must use glibc (Android bionic .so is not compatible)")
    check(not (needed & FORBIDDEN),
          f"Android-only runtime dependencies: {needed & FORBIDDEN}")
    versions = command("aarch64-linux-gnu-readelf", "-V", str(lib))
    glibc = {(int(a), int(b)) for a, b in
             re.findall(r"\bGLIBC_(\d+)\.(\d+)\b", versions)}
    check(bool(glibc), "Cannot determine required glibc symbol versions")
    check(max(glibc) <= (2, 44),
          f"Built driver requires GLIBC_{max(glibc)}, newer than ROCKNIX GLIBC_2.44")
    stdcxx = {(int(a), int(b), int(c)) for a, b, c in
              re.findall(r"\bGLIBCXX_(\d+)\.(\d+)\.(\d+)\b", versions)}
    if stdcxx:
        check(max(stdcxx) <= (3, 4, 36),
              f"Driver requires newer libstdc++ than ROCKNIX: {max(stdcxx)}")
    print(f"ELF verified: AArch64/glibc max {max(glibc)}; dependencies {sorted(needed)}")


def verify_driver(variant, out):
    folder = out / variant
    lib = folder / "libvulkan_freedreno.so"
    verify_elf(lib)

    icd = json.loads((folder / "freedreno_icd.aarch64.json").read_text())
    expected = str(INSTALL_ROOT / variant / lib.name)
    check(icd["ICD"]["library_path"] == expected,
          "Vulkan ICD library_path does not match the on-device install path")
    check(icd["ICD"]["library_arch"] == "64", "Incorrect ICD library_arch")

    wrapper = folder / "run-test.sh"
    check(wrapper.is_file() and wrapper.stat().st_mode & 0o111,
          "Test wrapper is not executable")
    env = dict(os.environ, TU_DEBUG="")
    result = subprocess.run(
        ["/bin/sh", str(wrapper), "env"], env=env,
        check=True, capture_output=True, text=True
    )
    exported = dict(line.split("=", 1) for line in result.stdout.splitlines()
                    if "=" in line)
    check(exported.get("VK_DRIVER_FILES") == str(folder / "freedreno_icd.aarch64.json"),
          "Test wrapper does not select its own Vulkan driver")
    check(exported.get("VK_ICD_FILENAMES") == exported["VK_DRIVER_FILES"],
          "Vulkan ICD compatibility variable differs")
    check(exported.get("TU_DEBUG", "") == ("sysmem" if variant == "sysmem" else ""),
          "TU_DEBUG must be enabled only for the sysmem experiment")

    check((folder / "SOURCE_NOTICE").is_file(), "Source notice missing")
    check((folder / "LICENSES").is_dir(), "License bundle missing")
    info = (folder / "BUILD_INFO.txt").read_text()
    check("e2ab6687d5ad700cc2b856af684aa014f9dae943" in info,
          "Wrong Mesa source commit in manifest")
    print(f"Driver, ICD and test wrapper verified: {variant}")


def verify_package(variant, out):
    archive = out / f"sm8250-turnip27-{variant}.tar.gz"
    checksum = out / f"{archive.name}.sha256"
    check(archive.is_file() and archive.stat().st_size > 100000,
          "Test tarball missing")
    recorded = checksum.read_text().split()[0]
    check(file_sha256(archive) == recorded, "SHA256 mismatch for test tarball")

    with tarfile.open(archive, "r:gz") as bundle:
        names = [member.name for member in bundle.getmembers()]
        check(all(n == variant or n.startswith(variant + "/") for n in names),
              "Tarball contains unexpected output paths")
        for suffix in ("libvulkan_freedreno.so",
                       "freedreno_icd.aarch64.json", "run-test.sh",
                       "BUILD_INFO.txt", "SOURCE_NOTICE"):
            check(f"{variant}/{suffix}" in names,
                  f"Required packaged file missing: {suffix}")
        packed_lib = bundle.extractfile(f"{variant}/libvulkan_freedreno.so")
        check(packed_lib is not None, "Packed driver cannot be read")
        packed_sha = hashlib.sha256(packed_lib.read()).hexdigest()
        check(packed_sha == file_sha256(out / variant / "libvulkan_freedreno.so"),
              "Packaged driver differs from verified build")
    print(f"Tarball checksum and files verified: {archive.name}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("variant", choices=VARIANTS)
    parser.add_argument("output_dir", type=Path)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check-elf", action="store_true")
    mode.add_argument("--test-package", action="store_true")
    args = parser.parse_args()
    verify_driver(args.variant, args.output_dir)
    if args.test_package:
        verify_package(args.variant, args.output_dir)


if __name__ == "__main__":
    main()
