#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 NoisyQubits
"""Package a tested app and the matching complete source archive."""

import argparse
import hashlib
import json
import plistlib
import subprocess
import tarfile
from pathlib import Path


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source-downloads", type=Path,
                    default=Path(".build/media-engines/downloads"),
                    help="Previously checksum-verified engine source archives")
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
app = root / "build/FileSpoke.app"
if not app.is_dir():
    raise SystemExit("Build the app first")
if subprocess.check_output(["git", "status", "--porcelain"], cwd=root).strip():
    raise SystemExit("Commit source changes before packaging a release")
subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
subprocess.run([str(app / "Contents/MacOS/FileSpoke"), "--selftest"], check=True)
with (app / "Contents/Info.plist").open("rb") as file:
    version = plistlib.load(file)["CFBundleShortVersionString"]
manifest = json.loads((app / "Contents/Resources/MediaEngines/manifest.json").read_text())
downloads = args.source_downloads.resolve()
for package in manifest["packages"]:
    archive = downloads / package["archive"]
    if not archive.is_file() or sha256(archive) != package["sha256"]:
        raise SystemExit(f"Missing or mismatched source archive: {package['archive']}")

release = root / "build/release"
release.mkdir(parents=True, exist_ok=True)
app_zip = release / f"FileSpoke-{version}.zip"
source_tar = release / f"FileSpoke-{version}-source.tar.gz"
subprocess.run(["ditto", "-c", "-k", "--keepParent", str(app), str(app_zip)], check=True)
files = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).split(b"\0")
with tarfile.open(source_tar, "w:gz") as out:
    for raw in files:
        if not raw:
            continue
        relative = Path(raw.decode())
        out.add(root / relative, arcname=f"FileSpoke-{version}/{relative}")
    for package in manifest["packages"]:
        archive = downloads / package["archive"]
        out.add(archive, arcname=f"FileSpoke-{version}/engine-archives/{archive.name}")
    out.add(app / "Contents/Resources/MediaEngines/manifest.json",
            arcname=f"FileSpoke-{version}/engine-manifest.json")
for path in [app_zip, source_tar]:
    print(f"{path.name}  SHA-256 {sha256(path)}  bytes {path.stat().st_size}")
