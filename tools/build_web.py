#!/usr/bin/env python3
"""Build the browser game from a clean staging project. Python standard library only."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
GENERATED_NAMES = {
    "index.html", "index.js", "index.wasm", "index.pck", "index.png", "index.icon.png",
    "index.apple-touch-icon.png", "index.audio.worklet.js", "index.audio.position.worklet.js",
    "index.service.worker.js", "index.offline.html", "index.manifest.json",
    "build-info.json", "third-party-notices.txt", ".nojekyll",
}


def find_godot(override):
    explicit = override or os.environ.get("GODOT")
    if explicit:
        candidate = Path(explicit).expanduser()
        if not candidate.is_file():
            raise SystemExit(f"The selected Godot executable does not exist: {candidate}")
        return str(candidate.resolve())
    candidates = [shutil.which("godot"),
                  "/Applications/Godot.app/Contents/MacOS/Godot",
                  str(Path.home() / "Downloads/Godot.app/Contents/MacOS/Godot")]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(Path(candidate).resolve())
    raise SystemExit("Godot not found. Set GODOT or pass --godot /path/to/godot (matching export templates required).")


def run_godot(binary, stage, *args):
    command = [binary, "--headless", "--path", str(stage), "--log-file", str(stage / "build.log"), *args]
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    # Godot can return zero after script parse failures, so inspect its diagnostics too.
    bad = ("SCRIPT ERROR:", "Parse Error:", "Failed to load script", "Export failed")
    if result.returncode or any(marker in result.stdout for marker in bad):
        print(result.stdout)
        raise SystemExit("Godot web build failed; see diagnostics above.")
    for line in result.stdout.splitlines():
        if "WARNING:" in line or "ERROR:" in line:
            print(line)


def build(args):
    binary = find_godot(args.godot)
    version = subprocess.check_output([binary, "--version"], text=True).strip()
    output = Path(args.output).resolve()
    # Refuse paths where cleanup could destroy source files.
    if output == ROOT or output in ROOT.parents or (output.exists() and any(output.glob("*.gd"))):
        raise SystemExit("Choose a dedicated build output directory, such as builds/web.")
    if output.exists():
        unknown = [path.name for path in output.iterdir() if path.name not in GENERATED_NAMES or not path.is_file()]
        if unknown:
            raise SystemExit(f"Output contains unrelated files; choose an empty dedicated directory: {', '.join(unknown)}")
    print(f"Building Breakfast Balls with Godot {version}", flush=True)
    with tempfile.TemporaryDirectory(prefix="breakfast-web-") as folder:
        stage = Path(folder)
        for name in ("project.godot", "export_presets.cfg"):
            shutil.copy2(ROOT / name, stage / name)
        shutil.copytree(ROOT / "game", stage / "game", ignore=shutil.ignore_patterns("source_blender", "*.blend", "*.blend1", ".DS_Store"))
        (stage / "web").mkdir()
        shutil.copy2(ROOT / "web/shell.html", stage / "web/shell.html")
        # Only staged imports are resized; retained source art and native exports are unchanged.
        # 512 px is >2x the largest in-game portrait and cuts browser transfer/memory costs.
        for portrait in (stage / "game/assets/portraits").glob("*.png"):
            settings = Path(str(portrait) + ".import")
            settings.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\ncompress/mode=0\nprocess/size_limit=512\n')
        run_godot(binary, stage, "--editor", "--import")
        destination = stage / ".godot" / "web-output"
        destination.mkdir()
        # Build in Godot's ignored directory so output cannot enter its own pack.
        run_godot(binary, stage, "--export-release", "Web", str(destination / "index.html"))
        required = ("index.html", "index.js", "index.wasm", "index.pck")
        if not all((destination / name).is_file() and (destination / name).stat().st_size for name in required):
            raise SystemExit("Export is incomplete.")
        if "$GODOT" in (destination / "index.html").read_text():
            raise SystemExit("Unexpanded Godot HTML placeholders remain.")
        (destination / ".nojekyll").touch()
        notices = [ROOT / "web/THIRD_PARTY_NOTICES.txt", *sorted((ROOT / "game/assets/fonts").glob("*OFL.txt"))]
        notice_parts = [f"{path.name}\n{'=' * len(path.name)}\n{path.read_text()}" for path in notices if path.is_file()]
        if notice_parts:
            (destination / "third-party-notices.txt").write_text("\n\n".join(notice_parts))
        manifest = {"game": "Breakfast Balls", "engine": version, "threads": False,
                    "renderer": "WebGL 2 / Compatibility", "files": {}}
        for path in sorted(destination.iterdir()):
            if path.is_file():
                data = path.read_bytes()
                manifest["files"][path.name] = {"bytes": len(data), "gzip_bytes": len(gzip.compress(data, mtime=0)),
                                                 "sha256": hashlib.sha256(data).hexdigest()}
        (destination / "build-info.json").write_text(json.dumps(manifest, indent=2) + "\n")
        output.mkdir(parents=True, exist_ok=True)
        # Replace only known generated files; never recursively delete an arbitrary user path.
        for old in output.iterdir():
            if old.is_file() and old.name in GENERATED_NAMES:
                old.unlink()
        shutil.copytree(destination, output, dirs_exist_ok=True)
    archive = output.parent / "breakfast-balls-web.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as package:
        for path in sorted(output.iterdir()):
            if path.is_file():
                package.write(path, path.name)
    total = sum(item["bytes"] for item in manifest["files"].values())
    compressed = sum(item["gzip_bytes"] for item in manifest["files"].values())
    print(f"Ready: {output}\nBundle: {total / 1048576:.1f} MiB raw; {compressed / 1048576:.1f} MiB estimated gzip\nArchive: {archive}")
    print("Preview: python3 tools/serve_web.py")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Godot executable (default: GODOT environment variable or local installation)")
    parser.add_argument("--output", default=str(ROOT / "builds/web"))
    build(parser.parse_args())
