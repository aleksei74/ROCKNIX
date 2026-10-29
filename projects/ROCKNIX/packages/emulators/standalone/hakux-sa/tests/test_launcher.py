#!/usr/bin/env python3
"""Verify hakuX ES settings propagate safely to the standalone frontend."""

import os
import subprocess
import tempfile
from pathlib import Path

PACKAGE = Path(__file__).resolve().parents[1]

SETTINGS = {
    "hakux_render_scale": "SCALE",
    "hakux_aspect_ratio": "ASPECT",
    "hakux_fxaa": "FXAA",
    "hakux_upscaling": "UPSCALE",
    "hakux_asynchronous_shaders": "ASYNC",
    "hakux_shader_prebuild": "PREBUILD",
}

STUB = """#!/bin/bash
set -eu
get_setting() {
    case "$1" in
        hakux_render_scale) printf '%s' "$T_SCALE" ;;
        hakux_aspect_ratio) printf '%s' "$T_ASPECT" ;;
        hakux_fxaa) printf '%s' "$T_FXAA" ;;
        hakux_upscaling) printf '%s' "$T_UPSCALE" ;;
        hakux_asynchronous_shaders) printf '%s' "$T_ASYNC" ;;
        hakux_shader_prebuild) printf '%s' "$T_PREBUILD" ;;
        *) return 1 ;;
    esac
}
"""

def launch(values):
    with tempfile.TemporaryDirectory(prefix="hakux-launcher-test-") as tmp:
        base = Path(tmp)
        game = base / "Example Xbox Game.iso"
        game.write_bytes(b"game")
        src = (PACKAGE / "scripts/start_hakux.sh").read_text()
        src = src.replace(". /etc/profile", ":")
        src = src.replace('set_kill set "-9 hakux-sa"', ":")
        src = src.replace('HDD="/storage/.config/hakux/hdd"', 'HDD="' + str(base / "hdd") + '"')
        src = src.replace("export HAKUX_NATIVE_BASE=/storage/.cache/hakux",
                          'export HAKUX_NATIVE_BASE="' + str(base / "cache") + '"')
        call = 'exec /usr/bin/hakux-sa "$1" "$HDD" "${HAKUX_ARGS[@]}"'
        assert call in src
        src = src.replace(call, 'printf "%s\\\\n" "$1" "$HDD" "${HAKUX_ARGS[@]}"')
        script = base / "launcher.sh"
        script.write_text(STUB + src.replace("#!/bin/bash", "", 1))
        os.chmod(script, 0o700)
        env = dict(os.environ, **{"T_" + key: values.get(key, "") for key in
                                  ("SCALE", "ASPECT", "FXAA", "UPSCALE", "ASYNC", "PREBUILD")})
        result = subprocess.run(["bash", str(script), str(game), "xbox"], env=env,
                                capture_output=True, text=True, check=True)
        lines = result.stdout.splitlines()
        assert lines[:2] == [str(game), str(base / "hdd")], lines
        return lines[2:]

def main():
    options = PACKAGE / "scripts/start_hakux.sh"
    subprocess.run(["bash", "-n", str(options)], check=True)
    assert launch({}) == []
    enabled = launch({"SCALE": "3", "ASPECT": "16:9", "FXAA": "1",
                      "UPSCALE": "sgsr", "ASYNC": "0", "PREBUILD": "1"})
    assert enabled == ["scale=3", "aspect=16:9", "fxaa=1", "upscale=sgsr",
                       "asyncpipe=0", "prebuild=1"], enabled
    disabled = launch({"SCALE": "1", "ASPECT": "4:3", "FXAA": "0",
                       "UPSCALE": "bilinear", "ASYNC": "1", "PREBUILD": "0"})
    assert disabled == ["scale=1", "aspect=4:3", "fxaa=0", "upscale=bilinear",
                        "asyncpipe=1", "prebuild=0"], disabled
    invalid = launch({"SCALE": "99", "ASPECT": "invalid", "FXAA": "false",
                      "UPSCALE": "$(touch /tmp/hakux-pwn)", "ASYNC": "3",
                      "PREBUILD": "unknown"})
    assert invalid == [], invalid
    print("hakuX launcher: defaults, explicit values and unsafe values pass")

if __name__ == "__main__":
    main()
