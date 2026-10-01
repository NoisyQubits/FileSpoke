#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 NoisyQubits
set -euo pipefail
cd "${0:A:h}"

engine_source="${FILESPOKE_ENGINE_RUNTIME:-}"
if [[ -z "$engine_source" ]]; then
  python3 Tools/build-media-engines.py
  engine_source=".build/media-engines/runtime"
fi
python3 Tools/verify-media-engines.py "$engine_source"

app="build/FileSpoke.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cp LICENSE "$app/Contents/Resources/LICENSE.txt"
cp Resources/ArchiveHeaders-LICENSE.txt "$app/Contents/Resources/ArchiveHeaders-LICENSE.txt"
sources=(Sources/App.swift Sources/Selftest.swift Sources/Core/*.swift Sources/Media/*.swift Sources/UI/*.swift Sources/Support/*.swift)
xcrun swiftc -O -j 10 -target arm64-apple-macosx14.0 -module-name FileSpoke \
  -I Sources/SystemArchive "${sources[@]}" -o "$app/Contents/MacOS/FileSpoke"
rm -rf "$app/Contents/Resources/MediaEngines"
ditto "$engine_source" "$app/Contents/Resources/MediaEngines"
python3 Tools/normalize-engine-manifest.py "$app/Contents/Resources/MediaEngines"
for binary in "$app"/Contents/Resources/MediaEngines/bin/* "$app"/Contents/Resources/MediaEngines/lib/*.dylib(N); do
  [[ -L "$binary" ]] && continue
  codesign --force --sign - "$binary"
done
python3 Tools/verify-media-engines.py "$app/Contents/Resources/MediaEngines" --refresh-signed-hashes
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
echo "Ready: $app"
