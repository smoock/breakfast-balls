#!/usr/bin/env python3
"""Publish the verified static build to its separate Vercel project."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import shutil
import subprocess

from build_web import GENERATED_NAMES, ROOT


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default="breakfast-balls")
    parser.add_argument("--scope", default="smoocks-projects")
    parser.add_argument("--vercel", help="Path to a current Vercel CLI executable")
    parser.add_argument("--prepare-only", action="store_true", help="Validate and stage files without calling Vercel")
    args = parser.parse_args()
    source = ROOT / "builds/web"
    target = ROOT / "builds/vercel"
    manifest_file = source / "build-info.json"
    if not manifest_file.is_file():
        raise SystemExit("Build first: python3 tools/build_web.py")
    manifest = json.loads(manifest_file.read_text())
    names = set(manifest["files"]) | {"build-info.json"}
    if not names <= GENERATED_NAMES or {path.name for path in source.iterdir()} != names:
        raise SystemExit("Unexpected files in the build. Rebuild in a clean dedicated output directory.")
    for name, details in manifest["files"].items():
        path = source / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != details["sha256"]:
            raise SystemExit(f"Build hash mismatch: {name}. Rebuild before publishing.")
    target.mkdir(parents=True, exist_ok=True)
    # Keep only Vercel's project-link metadata between publications.
    for path in target.iterdir():
        if path.name in (".vercel", ".gitignore", ".env.local", ".vercelignore"):
            continue
        if path.name not in GENERATED_NAMES | {"vercel.json"} or not path.is_file():
            raise SystemExit(f"Unexpected deployment file: {path}. Remove it manually or use a fresh builds/vercel directory.")
    for path in target.iterdir():
        if path.is_file() and path.name != ".gitignore":
            path.unlink()
    for name in names:
        shutil.copy2(source / name, target / name)
    shutil.copy2(ROOT / "web/vercel.json", target / "vercel.json")
    (target / ".vercelignore").write_text(".vercel\n.env*\n.gitignore\n")
    print(f"Verified {len(names)} build files. Staged in {target}", flush=True)
    if args.prepare_only:
        return
    cli = args.vercel or shutil.which("vercel")
    if not cli:
        raise SystemExit("Install the Vercel CLI and run vercel login, then retry. Staged files are ready.")
    version = subprocess.run([cli, "--version"], capture_output=True, text=True, check=True)
    match = re.search(r"(\d+)\.(\d+)\.(\d+)", version.stdout)
    if not match or tuple(map(int, match.groups())) < (47, 2, 2):
        raise SystemExit("Vercel CLI 47.2.2+ is required. Use a current CLI with --vercel, or run the pinned npx command in WEB.md.")
    subprocess.run([cli, "link", "--yes", "--project", args.project, "--scope", args.scope], cwd=target, check=True)
    # Current CLI versions download development credentials when linking. This
    # static site needs none; keep them out of every subsequent publication.
    (target / ".env.local").unlink(missing_ok=True)
    subprocess.run([cli, "deploy", "--prod", "--yes", "--scope", args.scope], cwd=target, check=True)


if __name__ == "__main__":
    main()
