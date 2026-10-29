#!/usr/bin/env python3
"""Offline source/packaging checks for the experimental hakuX Linux port."""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PACKAGE = Path(__file__).resolve().parents[1]
UPSTREAM = "e11ee60b90742a368a08f7f5339af10048a63a04"
PATCH = PACKAGE / "patches/0001-linux-sdl-vulkan-core.patch"


def run(*args, **kwargs):
    return subprocess.run(args, text=True, capture_output=True, check=True, **kwargs)


def main():
    pkg = (PACKAGE / "package.mk").read_text()
    assert 'PKG_VERSION="' + UPSTREAM + '"' in pkg
    assert 'PKG_TOOLCHAIN="manual"' in pkg
    for device in ("SM8250", "SM8550", "SM8750"):
        assert device in pkg
    assert "hakux-sa" in (PACKAGE / "scripts/start_hakux.sh").read_text()

    for name in ("package.mk", "scripts/start_hakux.sh"):
        run("bash", "-n", str(PACKAGE / name))
    for name in ("main.c", "audio_out.c", "vsync.c", "math_compat.c", "menu.c", "menu.h"):
        assert (PACKAGE / "sources/linux" / name).is_file(), name

    if len(sys.argv) < 2:
        print("Package and shell checks passed (pass upstream checkout to verify patch).")
        return

    upstream = Path(sys.argv[1]).resolve()
    assert run("git", "-C", str(upstream), "rev-parse", "HEAD").stdout.strip() == UPSTREAM

    with tempfile.TemporaryDirectory(prefix="hakux-port-check-") as temp:
        proc = subprocess.Popen(
            ["git", "-C", str(upstream), "archive", "--format=tar", "HEAD"],
            stdout=subprocess.PIPE,
        )
        subprocess.run(["tar", "-x", "-C", temp], stdin=proc.stdout, check=True)
        proc.stdout.close()
        assert proc.wait() == 0
        run("patch", "--batch", "--forward", "-p1", "-d", temp, "-i", str(PATCH))

        source = Path(temp)
        code = (source / "hw/xbox/hle/vk/swapchain.c").read_text()
        assert "SDL_Vulkan_CreateSurface" in code
        assert "VkAndroidSurfaceCreateInfoKHR" in code
        assert "HakuXWindow" in code
        assert "menu_upload(cb)" in code
        assert "menu_draw(cb, f, iw, ih)" in code
        vk = (source / "hw/xbox/hle/vk/vkdev.c").read_text()
        assert "SDL_Vulkan_GetInstanceExtensions" in vk
        cmake = (source / "native/CMakeLists.txt").read_text()
        assert "add_executable(hakux-sa" in cmake
        assert "find_package(SDL3 CONFIG REQUIRED)" in cmake
        assert 'linux/math_compat.c' in cmake
        assert 'linux/menu.c' in cmake
        for name in ("native/kernel/fixups.c", "native/core/memscan.c",
                     "native/dev/nv2a.c", "native/app/present.c"):
            assert "#include <sys/system_properties.h>" not in (source / name).read_text()
        for name in ("main.c", "audio_out.c", "vsync.c", "math_compat.c", "menu.c", "menu.h"):
            shutil.copy2(PACKAGE / "sources/linux" / name, source / name)

    print("hakuX upstream patch, Linux sources and packaging checks passed.")


if __name__ == "__main__":
    main()
