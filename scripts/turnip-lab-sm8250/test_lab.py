#!/usr/bin/env python3
"""Offline pre-flight tests for the SM8250 driver-only Actions recipe."""

import argparse
import hashlib
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent))
import verify

ROOT = Path(__file__).resolve().parents[2]
BUILD = Path(__file__).with_name("build.sh")
WORKFLOW = ROOT / ".github/workflows/sm8250-turnip-lab.yml"
ANCHOR = "gmem_bandwidth = (gmem_bandwidth * 11 + total_draw_call_bandwidth) / 10;"
REPLACEMENT = "gmem_bandwidth = (gmem_bandwidth * 10 + total_draw_call_bandwidth) / 10;"
PIN_SHA = "8d7330494161779ff3e7257315fe8801c845dc6b5bbc1cdc59dfc834abadd670"
SOURCE_COMMIT = "e2ab6687d5ad700cc2b856af684aa014f9dae943"


class RecipeTests(unittest.TestCase):
    def test_shell_syntax(self):
        subprocess.run(["bash", "-n", str(BUILD)], check=True)

    def test_metadata_and_scope(self):
        source = BUILD.read_text()
        workflow = WORKFLOW.read_text()
        self.assertIn(PIN_SHA, source)
        self.assertIn(SOURCE_COMMIT, source)
        self.assertIn("ubuntu:24.04", workflow)
        self.assertIn("glslang-tools spirv-tools", workflow)
        self.assertIn("glslangValidator --version", workflow)
        self.assertIn("aarch64-ubuntu24.ini", source)
        self.assertIn("URIs: http://ports.ubuntu.com/ubuntu-ports", workflow)
        self.assertIn("Architectures: arm64", workflow)
        self.assertIn("/^URIs:/i Architectures: amd64", workflow)
        self.assertIn("SM8250 Turnip 27 Lab", workflow)
        self.assertIn("sm8250-turnip27", workflow)
        self.assertIn("baseline|sysmem|autotune", source)
        self.assertIn('cp -a "$mesa/licenses"', source)
        self.assertIn('cp "$source_root/drivers/LICENSE"', source)
        self.assertNotIn('cp -a "$source_root/LICENSES"', source)
        self.assertNotIn("make SM8250", workflow)
        self.assertNotIn("build_distro", workflow)
        try:
            import yaml
        except ImportError:
            return
        data = yaml.safe_load(workflow)
        self.assertEqual(data["jobs"]["build"]["container"]["image"],
                         "ubuntu:24.04")
        inputs = data.get("on", data.get(True))["workflow_dispatch"]["inputs"]
        self.assertEqual(inputs["variant"]["options"],
                         ["baseline", "sysmem", "autotune"])

    def test_validation_accepts_safe_linux_glibc(self):
        with tempfile.TemporaryDirectory() as folder:
            lib = Path(folder) / "libvulkan_freedreno.so"
            lib.write_bytes(b"\0" * 100001)

            def readelf(*args):
                if "-h" in args:
                    return "Class: ELF64\nMachine: AArch64\n"
                if "-d" in args:
                    return "Shared library: [libc.so.6]\nShared library: [libdrm.so.2]\n"
                return "Name: GLIBC_2.17\nName: GLIBC_2.36\nName: GLIBCXX_3.4.30\n"

            with patch.object(verify, "command", side_effect=readelf):
                verify.verify_elf(lib)

    def test_validation_rejects_new_glibc(self):
        with tempfile.TemporaryDirectory() as folder:
            lib = Path(folder) / "libvulkan_freedreno.so"
            lib.write_bytes(b"\0" * 100001)

            def readelf(*args):
                if "-h" in args:
                    return "Class: ELF64\nMachine: AArch64\n"
                if "-d" in args:
                    return "Shared library: [libc.so.6]\n"
                return "Name: GLIBC_2.17\nName: GLIBC_2.45\n"

            with patch.object(verify, "command", side_effect=readelf):
                with self.assertRaisesRegex(ValueError, "ROCKNIX GLIBC_2.44"):
                    verify.verify_elf(lib)

    def test_validation_rejects_android(self):
        with tempfile.TemporaryDirectory() as folder:
            lib = Path(folder) / "libvulkan_freedreno.so"
            lib.write_bytes(b"\0" * 100001)

            def readelf(*args):
                if "-h" in args:
                    return "Class: ELF64\nMachine: AArch64\n"
                return "Shared library: [libhardware.so]\nShared library: [libc.so.6]\n"

            with patch.object(verify, "command", side_effect=readelf):
                with self.assertRaisesRegex(ValueError, "Android-only"):
                    verify.verify_elf(lib)


def inspect_source_archive(archive):
    digest = hashlib.sha256()
    with archive.open("rb") as f:
        for chunk in iter(lambda: f.read(1048576), b""):
            digest.update(chunk)
    if digest.hexdigest() != PIN_SHA:
        raise SystemExit("Pinned Mesa archive SHA256 does not match")

    prefix = "DD-Turnip-v0.3.4-source/"
    with tarfile.open(archive, "r:xz") as tar:
        def read(path):
            f = tar.extractfile(prefix + path)
            if f is None:
                raise ValueError(f"Missing {path}")
            return f.read().decode("utf-8", errors="replace")

        assert read("mesa/VERSION").strip() == "27.0.0-devel"
        assert SOURCE_COMMIT in read("NOTICE")
        assert "MIT License" in read("mesa/licenses/MIT")
        assert read("mesa/docs/license.rst").strip()
        assert read("drivers/LICENSE").strip()
        text = read("mesa/src/freedreno/vulkan/tu_autotune.cc")
        assert text.count(ANCHOR) == 1
        modified = text.replace(ANCHOR, REPLACEMENT)
        assert modified.count(REPLACEMENT) == 1
        print("Pinned release source, Mesa commit and single autotune patch anchor verified")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("--source-archive", type=Path)
    args, extra = parser.parse_known_args()
    if args.source_archive:
        inspect_source_archive(args.source_archive)
    unittest.main(argv=[sys.argv[0]] + extra)
