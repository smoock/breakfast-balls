#!/usr/bin/env python3
"""Install the pinned official Linux editor and web templates, verifying SHA-512."""
import hashlib
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile

VERSION = "4.7.2"
RELEASE = VERSION + "-stable"
BASE_URL = "https://github.com/godotengine/godot-builds/releases/download/" + RELEASE + "/"
WEB_TEMPLATES = ("web_nothreads_debug.zip", "web_nothreads_release.zip")


def main():
    if platform.system() != "Linux" or platform.machine() not in ("x86_64", "amd64"):
        raise SystemExit("Cloud installation requires Linux x86_64. On Mac, use your existing Godot 4.7.2 installation.")
    data_home = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    install = data_home / "breakfast-balls" / ("godot-" + VERSION)
    binary = install / "godot"
    templates = data_home / "godot/export_templates" / (VERSION + ".stable")
    link = Path.home() / ".local/bin/godot"
    if binary.is_file() and all((templates / name).is_file() for name in WEB_TEMPLATES):
        actual = subprocess.check_output([str(binary), "--version"], text=True).strip()
        if actual.startswith(VERSION + ".stable."):
            print("Reusing Godot " + actual, flush=True)
            link.parent.mkdir(parents=True, exist_ok=True)
            if link.is_symlink() and link.resolve() == binary.resolve():
                return
            if link.exists() or link.is_symlink():
                raise SystemExit(f"Refusing to replace an existing executable: {link}")
            link.symlink_to(binary)
            return
    if link.exists() or link.is_symlink():
        if not link.is_symlink() or link.resolve() != binary.resolve():
            raise SystemExit(f"Refusing to replace an existing executable: {link}")
    editor_name = "Godot_v" + RELEASE + "_linux.x86_64.zip"
    templates_name = "Godot_v" + RELEASE + "_export_templates.tpz"
    with tempfile.TemporaryDirectory(prefix="breakfast-godot-") as folder:
        work = Path(folder)
        sums_path = work / "SHA512-SUMS.txt"
        urllib.request.urlretrieve(BASE_URL + sums_path.name, sums_path)
        sums = {}
        for line in sums_path.read_text().splitlines():
            fields = line.split()
            if len(fields) == 2:
                sums[fields[1].lstrip("*")] = fields[0].lower()
        for name in (editor_name, templates_name):
            expected = sums.get(name, "")
            if len(expected) != 128:
                raise SystemExit("Official checksum missing for " + name)
            archive = work / name
            print("Downloading " + name, flush=True)
            urllib.request.urlretrieve(BASE_URL + name, archive)
            digest = hashlib.sha512()
            with archive.open("rb") as source:
                for chunk in iter(lambda: source.read(1024 * 1024), b""):
                    digest.update(chunk)
            if digest.hexdigest() != expected:
                raise SystemExit("SHA-512 mismatch for " + name)
            print("Verified " + name, flush=True)
        install.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(work / editor_name) as archive:
            with archive.open(editor_name[:-4]) as source, binary.open("wb") as target:
                shutil.copyfileobj(source, target)
        binary.chmod(0o755)
        templates.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(work / templates_name) as archive:
            for name in WEB_TEMPLATES:
                with archive.open("templates/" + name) as source, (templates / name).open("wb") as target:
                    shutil.copyfileobj(source, target)
    link.parent.mkdir(parents=True, exist_ok=True)
    if not link.is_symlink():
        link.symlink_to(binary)
    subprocess.run([str(link), "--version"], check=True)
    print("Installed editor and matching single-threaded web templates.")


if __name__ == "__main__":
    main()
