# SM8250 Turnip 27 lab

An opt-in, **driver-only** GitHub Actions experiment for the Snapdragon 865 /
Adreno 650 ROCKNIX target. It does not modify the system Mesa package, create a
firmware image, or affect SM8550/SM8750.

## Run it

1. Open [SM8250 Turnip 27 Lab](https://github.com/aleksei74/ROCKNIX/actions/workflows/sm8250-turnip-lab.yml).
2. Select **Run workflow**, branch **next**, and one of:
   - **baseline**: Mesa 27 with no experimental source changes.
   - **sysmem**: the **same baseline source**; `run-test.sh` enables
     `TU_DEBUG=sysmem` at runtime. No new source patch is needed.
   - **autotune**: a single public, opt-in GMEM bandwidth weight change
     (`11` to `10`), from Droid-Deck/Drivers.
3. Download the resulting `sm8250-turnip27-<variant>-<run>` Actions artifact.
   Inside is a `sm8250-turnip27-<variant>.tar.gz` and a SHA256 file.

Or launch using GitHub CLI:

```sh
gh workflow run sm8250-turnip-lab.yml -R aleksei74/ROCKNIX --ref next -f variant=baseline
gh workflow run sm8250-turnip-lab.yml -R aleksei74/ROCKNIX --ref next -f variant=sysmem
gh workflow run sm8250-turnip-lab.yml -R aleksei74/ROCKNIX --ref next -f variant=autotune
```

The job installs an ARM64 cross compiler in an isolated **Ubuntu 24.04** build
container, including glslangValidator >= 12.2 and SPIR-V tools required by
Mesa 27. This targets glibc 2.39 (compatible with the current ROCKNIX
glibc 2.44 package).
It produces a Linux **DRM/MSM + KGSL**, Wayland/X11 Turnip Vulkan ICD, not an
Android Bionic driver. The built library is checked for architecture, shared
libraries, glibc version and C++ ABI requirements before upload.

The Mesa snapshot is pinned to the exact **27.0.0-devel** commit
`e2ab6687d5ad700cc2b856af684aa014f9dae943`, distributed as
`DD-Turnip-v0.3.4-source.tar.xz`. The download has an enforced SHA256. The
source archive is **pristine Mesa** for the baseline experiment; the lab
does **not** reproduce TurnipZ's unpublished changes. The autotune tweak is
based on this published [Droid-Deck change](https://github.com/Droid-Deck/Drivers/blob/main/patches/scripts/autotune_bandwidth.py).

## Install for a test on an SM8250 device

Copy the downloaded `.tar.gz` to the device and extract under the persistent
storage folder:

```sh
mkdir -p /storage/.config/turnip-test
tar -xzf sm8250-turnip27-baseline.tar.gz -C /storage/.config/turnip-test

/storage/.config/turnip-test/baseline/run-test.sh
```

The last command runs `vulkaninfo --summary` using **only** the experimental
driver. To run a Vulkan application with it:

```sh
/storage/.config/turnip-test/baseline/run-test.sh /path/to/vulkan-app arguments...
```

Use `sysmem` or `autotune` instead of `baseline` for the other artifact
variants. The ICD JSON has an absolute path for this installation directory;
do not put it somewhere else without adjusting `library_path`. The wrapper
sets `VK_DRIVER_FILES` and the legacy `VK_ICD_FILENAMES` for one process.
When the selected variant is `sysmem`, it also adds `TU_DEBUG=sysmem`.

**Normal games are unaffected.** To revert, launch them without the wrapper.
Do not copy the experimental library over `/usr/lib/libvulkan_freedreno.so`.
When testing via an ES launcher, check that the launcher does not clear
`VK_DRIVER_FILES` using its existing driver-selection logic; testing with
`vulkaninfo` first isolates that issue.

## Verification and known limitations

Build validation happens in Actions, but **real SM8250 GPU compatibility cannot
be proven by cross-compiling**. Confirm the driver loads and renders in the
target device before collecting game benchmark data. If the driver fails, the
original firmware and system Mesa are unchanged.

A pinned Linux Mesa 27 snapshot may not load on every ROCKNIX build, even with
a compatible glibc version, due to kernel DRM/MSM, Vulkan loader and other
runtime dependencies. The job reports link requirements and
rejects drivers needing glibc newer than the current ROCKNIX 2.44 package.
Compare identical game scenes under the same clocks,
thermal conditions, emulator version and shader-cache state. Also test
correctness: UBWC artifacts, shader compilation stalls, hangs and exits.

A new source modification or another Mesa snapshot requires changing the
recipe and reviewing its license and compatibility. Re-running the same
`variant` needs no new commit.
