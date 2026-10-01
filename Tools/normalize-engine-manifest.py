#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 NoisyQubits
"""Remove machine-local build paths from a verified runtime's public manifest."""

import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("root", type=Path)
args = parser.parse_args()
manifest_path = args.root / "manifest.json"
manifest = json.loads(manifest_path.read_text())
if manifest.get("schema") != 1 or manifest.get("target") != "arm64-apple-macos14":
    raise SystemExit("Unexpected media-engine manifest")
for package in manifest["packages"]:
    package.pop("configure", None)
manifest["sdk"] = Path(manifest["sdk"]).name
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
