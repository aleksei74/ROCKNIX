# hakuX on ROCKNIX SM8250 / SM8550 / SM8750

Experimental standalone Linux port, separate from xemu-sa. On SM8250, SM8550,
and SM8750 the Xbox system offers hakuX as an optional emulator; xemu remains
the default.

## Sources and build

- hakuX: rfandango/hakuX, e11ee60b90742a368a08f7f5339af10048a63a04
- FEX submodule: pinned by upstream hakuX (52018bf46a8279b22bce738548ab3f40db467064)
- Third-party sources: pinned in package.mk and fetched into .hakux-deps
- Package: projects/ROCKNIX/packages/emulators/standalone/hakux-sa
- Target: hakux-sa (ARM64, glibc, SDL3, Vulkan, FEX)
- Install: /usr/bin/hakux-sa and /usr/bin/start_hakux.sh
- User data: /storage/.config/hakux/hdd; GPU cache: /storage/.cache/hakux

The unmodified xemu-sa remains the supported fallback. hakuX does not use
xemu's BIOS or qcow2 hard disk. Its HDD is a separate host directory; do not
point it at xemu's existing image.

## Portability work

Patch 0001 separates Android-specific Vulkan window handling (ANativeWindow,
VK_KHR_android_surface) from Linux SDL3 Wayland Vulkan surfaces and instance
extensions. On Linux it selects hakuX's existing GPU upload/readback fallback
instead of its Android HardwareBuffer zero-copy import.

The Linux frontend supplies an SDL3 window, Xbox pad input and a 60 Hz display
clock. The Linux audio sink uses SDL3 and preserves the APU's producer/consumer
queue semantics. The core keeps the upstream FEX-based Xbox kernel, graphics,
save states, mods, and network code.

## Verification gates

1. Fresh upstream source applies every package patch with zero rejects.
2. Shell scripts and ROCKNIX package have valid syntax.
3. ARM64 CMake configure succeeds using the ROCKNIX sysroot and pinned deps.
4. hakux-sa links; ELF interpreter and dependencies match the device.
5. Test Wayland presentation, audio, controller, Xbox game image boot, resume,
   GPU reset, and exit on real SM8250, SM8550, and SM8750 devices.
6. Confirm all three devices offer hakuX in ES, with the stock Vulkan driver
   available on SM8250/SM8550 and the optional per-game Turnip selector on
   SM8750. Other devices must retain xemu-only settings.

Current status: ARM64 Linux compile and link pass for SM8750 (2026-10-29).
SM8250 and SM8550 have not completed their own target builds or device tests.
The verified standalone binary is at
/tmp/hakux-sm8750-config-check/hakux-sa (AArch64, glibc, SDL3); the file is
not yet installed into a device image. Linux-only
pthread size checks, C header fixes, and FEX/HLE extension visibility were
rebased into the ROCKNIX patch. A small Linux math shim avoids a
GLIBC_2.43-only remainder symbol when linking with newer sysroots: the
resulting binary's maximum required GLIBC symbol version is 2.38. The fresh
upstream source patch test passes, but device runtime still needs independent
validation. Building the binary is not proof of game boot,
compatibility or runtime safety.

For a controlled test, use the normal ROCKNIX package build tooling during
the repository's permitted local build window, without cleaning other
packages or overwriting the existing xemu installation.
