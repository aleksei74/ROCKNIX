# SDM845 official OpenABL baseline

This integration uses ROCKNIX/distribution `next` at
`2a01f59e3329fd14923ccbe6f703cd84f0367196`, merged into ROCKNIXK `dev`
at `f7385a9200da7a7c419daf4c000932926c987fa4`.

The SDM845 device sources, M0/M2 quirks, ALSA/PipeWire patches, OpenABL
package and standard image boot routing follow the official implementation.
SDM845 selects Linux 7.1.2 and OpenABL 1.2. Boot files use `/dtbs`,
`/loader/entries` and `/openabl`.

The previous U-Boot carrier, GRUB defaults, slot-success service and custom
gamepad driver are excluded from this baseline. The Odin LED GUI, backend
and existing scan trigger are restored with official M0/M2 compatibility. Their
previous implementation remains in Git history. Generic fork emulator,
Eden, BIOS and T618 support is retained; remaining Odin enhancements require a
separate compatibility pass against the official drivers and model names.

An existing U-Boot/GRUB installation is not a verified migration path for
this baseline. Initial OpenABL installation and subsequent tar updates must
be tested separately. The official update script can write both internal
ABL partitions; no device installation was performed for this integration.

Reference: [OpenABL v1.2](https://github.com/OpenHandheldCollective/OpenABL/tree/v1.2).

## Host verification

Run from the repository root:

```sh
python3 -m unittest discover -s tools/tests -v
make -n SDM845
```

The host tests exercise BLS entry generation, OpenABL dependency selection,
the single SDM845 image definition, kernel recipe selection and the build
target. They do not establish successful compilation or device operation.

The checked integration has exact upstream source parity for the SDM845
device/platform/Odin quirk/audio groups and the OpenABL/BLS image helpers.
No full image build or M0/M2 hardware test was performed.

Inherited validation issues, also present before integration:

- RK3576 `090-ui_service` has an extra trailing `fi` rejected by `bash -n`.
- `update-kernel-configs-docs.yml` contains an existing `if: false` actionlint warning.
- Imported upstream patch files contain whitespace in patch context/signatures;
  those original patches are preserved verbatim.

## LED integration

LED configuration uses the same persistent-file flock protocol as native
system settings. Native SDM845 LED commands delegate to the GUI backend
when installed, and suspend uses temporary poweroff. This preserves saved
channel states and effects across native status updates and battery alerts.
Saving GUI settings re-enables the native active LED mode. An all-off user
configuration suppresses visible low-battery flashes.

Host tests also cover the real shell settings/suspend/low-battery script
paths. Build the GUI CTest with BUILD_TESTING=ON; firmware packaging disables
host tests. The GUI has retry and a 10-second backend timeout. Host and ARM64
GUI compilation passed; physical LEDs, the scan module against official
Linux 7.1.2, and a complete firmware image still require validation.
