#!/usr/bin/env bash
set -euo pipefail

variant="${1:?usage: build.sh <baseline|sysmem|autotune> <output-dir> <work-dir>}"
out_dir="${2:?missing output directory}"
work_dir="${3:?missing temporary work directory}"

case "$variant" in
  baseline|sysmem|autotune) ;;
  *) echo "Unknown experiment: $variant" >&2; exit 2 ;;
esac

mesa_commit="e2ab6687d5ad700cc2b856af684aa014f9dae943"
source_version="DD-Turnip-v0.3.4"
source_url="https://github.com/Droid-Deck/Drivers-CI/releases/download/${source_version}/${source_version}-source.tar.xz"
source_sha256="8d7330494161779ff3e7257315fe8801c845dc6b5bbc1cdc59dfc834abadd670"
install_root="/storage/.config/turnip-test"

mkdir -p "$work_dir" "$out_dir"
archive="$work_dir/${source_version}-source.tar.xz"
if [ ! -s "$archive" ]; then
  curl --fail --location --retry 3 --connect-timeout 15 \
    --output "$archive" "$source_url"
fi
printf '%s  %s\n' "$source_sha256" "$archive" | sha256sum --check

source_root="$work_dir/source"
rm -rf "$source_root"
mkdir -p "$source_root"
tar -xJf "$archive" --strip-components=1 -C "$source_root"
mesa="$source_root/mesa"

if [ "$(tr -d '[:space:]' < "$mesa/VERSION")" != "27.0.0-devel" ]; then
  echo "Unexpected Mesa version in pinned source archive" >&2
  exit 1
fi
grep -Fq "$mesa_commit" "$source_root/NOTICE" || {
  echo "Mesa commit metadata does not match the pinned release" >&2
  exit 1
}

if [ "$variant" = "autotune" ]; then
  python3 - "$mesa/src/freedreno/vulkan/tu_autotune.cc" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
original = "gmem_bandwidth = (gmem_bandwidth * 11 + total_draw_call_bandwidth) / 10;"
modified = "gmem_bandwidth = (gmem_bandwidth * 10 + total_draw_call_bandwidth) / 10;"
data = p.read_text()
if data.count(original) != 1:
    raise SystemExit("Autotune patch anchor missing or ambiguous; refusing to build")
p.write_text(data.replace(original, modified))
print("Applied the public Droid-Deck GMEM bandwidth multiplier change")
PY
fi

cat > "$work_dir/aarch64-ubuntu24.ini" <<'INI'
[binaries]
c = ['ccache', 'aarch64-linux-gnu-gcc']
cpp = ['ccache', 'aarch64-linux-gnu-g++']
ar = 'aarch64-linux-gnu-ar'
strip = 'aarch64-linux-gnu-strip'
pkg-config = 'pkg-config'
wayland-scanner = '/usr/bin/wayland-scanner'

[properties]
sys_root = '/'
pkg_config_libdir = '/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig'

[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
INI

export PKG_CONFIG_LIBDIR="/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="/"
export CCACHE_DIR="${CCACHE_DIR:-$work_dir/ccache}"
mkdir -p "$CCACHE_DIR"

build="$work_dir/build"
meson setup "$build" "$mesa" --cross-file "$work_dir/aarch64-ubuntu24.ini" \
  --buildtype=release --prefix=/usr \
  -Dvulkan-drivers=freedreno -Dfreedreno-kmds=msm,kgsl \
  -Dgallium-drivers= -Dplatforms=wayland,x11 \
  -Dopengl=false -Dgbm=disabled -Dglx=disabled -Degl=disabled \
  -Dllvm=disabled -Dvulkan-layers= -Dtools= -Dvideo-codecs= \
  -Dxmlconfig=disabled -Dbuild-tests=false

ninja -C "$build" -j "${BUILD_JOBS:-4}" \
  src/freedreno/vulkan/libvulkan_freedreno.so

driver="$build/src/freedreno/vulkan/libvulkan_freedreno.so"
test -s "$driver"

variant_dir="$out_dir/$variant"
mkdir -p "$variant_dir"
aarch64-linux-gnu-strip -o "$variant_dir/libvulkan_freedreno.so" "$driver"

cat > "$variant_dir/freedreno_icd.aarch64.json" <<EOF
{
  "file_format_version": "1.0.1",
  "ICD": {
    "library_path": "$install_root/$variant/libvulkan_freedreno.so",
    "library_arch": "64",
    "api_version": "1.4.0"
  }
}
EOF

cat > "$variant_dir/run-test.sh" <<'EOF'
#!/bin/sh
set -eu
here="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
export VK_DRIVER_FILES="$here/freedreno_icd.aarch64.json"
export VK_ICD_FILENAMES="$VK_DRIVER_FILES"
if [ "$(basename "$here")" = "sysmem" ]; then
  export TU_DEBUG="sysmem${TU_DEBUG:+,$TU_DEBUG}"
fi
if [ "$#" -eq 0 ]; then
  set -- vulkaninfo --summary
fi
exec "$@"
EOF
chmod 755 "$variant_dir/run-test.sh"

cp "$source_root/NOTICE" "$variant_dir/SOURCE_NOTICE"
mkdir -p "$variant_dir/LICENSES"
cp -a "$mesa/licenses" "$variant_dir/LICENSES/mesa"
cp "$mesa/docs/license.rst" "$variant_dir/LICENSES/mesa-license.rst"
cp "$source_root/drivers/LICENSE" "$variant_dir/LICENSES/Droid-Deck-LICENSE"

cat > "$variant_dir/BUILD_INFO.txt" <<EOF
Device: SM8250 (Snapdragon 865 / Adreno 650)
Driver: Mesa 27.0.0-devel Linux AArch64 (glibc), MSM/DRM and KGSL backends
Mesa commit: $mesa_commit
Source release: $source_url
Source SHA256: $source_sha256
Variant: $variant
EOF

case "$variant" in
  baseline)
    printf 'Changes: none (pristine Mesa source)\n' >> "$variant_dir/BUILD_INFO.txt"
    ;;
  sysmem)
    printf 'Changes: none; run-test.sh sets TU_DEBUG=sysmem at runtime\n' >> "$variant_dir/BUILD_INFO.txt"
    ;;
  autotune)
    printf 'Changes: gmem_bandwidth multiplier 11 -> 10 in tu_autotune.cc\n' >> "$variant_dir/BUILD_INFO.txt"
    printf 'Source: https://github.com/Droid-Deck/Drivers/blob/main/patches/scripts/autotune_bandwidth.py\n' \
      >> "$variant_dir/BUILD_INFO.txt"
    ;;
esac

python3 "$(dirname "$0")/verify.py" "$variant" "$out_dir" --check-elf

tarball="$out_dir/sm8250-turnip27-$variant.tar.gz"
tar -C "$out_dir" -czf "$tarball" "$variant"
(cd "$out_dir" && sha256sum "$(basename "$tarball")" > "$(basename "$tarball").sha256")

cat > "$out_dir/README.txt" <<EOF
SM8250 Turnip 27 lab: $variant

THIS IS AN EXPERIMENTAL DRIVER, NOT A SYSTEM MESA REPLACEMENT.
The driver has not yet been tested on a ROCKNIX SM8250 device.

Install on the SM8250 device:
  mkdir -p /storage/.config/turnip-test
  tar -xzf sm8250-turnip27-$variant.tar.gz -C /storage/.config/turnip-test

Verify Vulkan driver loading on the device:
  /storage/.config/turnip-test/$variant/run-test.sh

Launch a Vulkan program with this driver:
  /storage/.config/turnip-test/$variant/run-test.sh <command> [arguments...]

To revert, run the program as usual without this wrapper.
This does not overwrite the system Vulkan driver or Mesa files.
For sysmem, the wrapper adds TU_DEBUG=sysmem when launching the program.
Mesa source: $mesa_commit (Droid-Deck source release $source_version)
EOF

echo "Created $tarball"
echo "Mesa $mesa_commit, variant=$variant, system driver untouched"
