# Restore Odin LED GUI on the official baseline

Goal: restore the existing LED GUI and effects, adapting the backend to official M0/M2 models and LED support without restoring old boot/touch/input overrides.

- [x] Restore only GUI/backend/registration, existing scan trigger, LED restore/sleep hooks and their package dependencies.
- [x] Reproduce M0 rejection, unavailable-channel coupling and unavailable-trigger restore failures in host tests, then fix their root causes.
- [x] Add GUI retry and bounded backend calls; log backend errors, exercise real QProcess behavior and preserve existing preview tests.
- [x] Compile the GUI with existing Qt/cache, run host regression checks, review and commit locally. Do not access devices or push.

The user's physical LED failure is not yet reproduced on hardware. Do not claim these source defects prove that failure's cause.

Findings: existing exclusive-file settings lock conflicts with native persistent
flock; fixed and tested against actual shell sort_settings. Native low-battery
and sleep paths are bridged to saved channel state; shared SM8250 unchanged.
Validation: 67 Python tests, C++ retry/timeout CTest, preview/feedback tests,
host and ARM64 GUI compilation pass. No device or full image/module build.
