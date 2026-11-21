#!/usr/bin/env python3
"""Repeatable, offline checks for a checkout; optionally build the web export."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from install_cloud_godot import VERSION

SUITES = ("golf_tests.gd", "web_compat_tests.gd", "online_game_tests.gd", "export_asset_tests.gd")
BAD_DIAGNOSTICS = ("SCRIPT ERROR:", "Parse Error:", "Failed to load script", "ERROR:")


def run(command, label, godot=False, timeout=600):
    print("\n== " + label + " ==", flush=True)
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=timeout)
    print(result.stdout, end="", flush=True)
    if result.returncode or (godot and any(marker in result.stdout for marker in BAD_DIAGNOSTICS)):
        raise SystemExit(label + " failed. Inspect diagnostics above.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-web", action="store_true")
    args = parser.parse_args()
    candidates = [os.environ.get("GODOT"), str(Path.home() / ".local/bin/godot"),
                  shutil.which("godot"), "/Applications/Godot.app/Contents/MacOS/Godot",
                  str(Path.home() / "Downloads/Godot.app/Contents/MacOS/Godot")]
    binary = next((path for path in candidates if path and Path(path).is_file()), None)
    if not binary:
        raise SystemExit("Godot missing. Run bash tools/setup_cloud.sh, or set GODOT to the executable path.")
    actual = subprocess.check_output([binary, "--version"], text=True).strip()
    if not actual.startswith(VERSION + ".stable."):
        raise SystemExit(f"Expected Godot {VERSION}.stable; found {actual}")
    if not Path("/private/tmp").is_dir():
        raise SystemExit("Test fixture directory /private/tmp is missing. Run tools/setup_cloud.sh on Linux.")
    print("Engine: " + actual, flush=True)
    base = [binary, "--headless", "--path", str(ROOT)]
    run(base + ["--editor", "--import"], "Import project and assets", godot=True)
    for name in SUITES:
        run(base + ["--script", "res://tests/" + name], name, godot=True)
    node_tests = sorted(str(path.relative_to(ROOT)) for path in (ROOT / "tests").glob("*.test.mjs"))
    if not node_tests:
        raise SystemExit("No Node server tests found.")
    run(["node", "--test", *node_tests], "Node server tests")
    if args.build_web:
        run([sys.executable, "tools/build_web.py", "--godot", binary], "Web export", timeout=1200)
    print("\nCloud checks passed. Browser journeys and human playtesting are separate checks.")


if __name__ == "__main__":
    main()
