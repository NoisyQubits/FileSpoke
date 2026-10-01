# FileSpoke

FileSpoke is a local macOS file converter and editor built around a Finder drag
wheel. Hold **Shift** while dragging files to choose an output format. Hold
**Shift–Option** for editing tools. You can also choose files from its menu bar
icon. Outputs are new files beside the originals; earlier outputs are preserved.

It handles images, video, audio, PDF, text/subtitles, and archives. PDF tools
include merge, split, page organization, compression, metadata, and QR reading.
Image, video, and audio tools include the editors exposed in the wheel and tool
catalog. The app runs locally and does not upload files or download executable
code after installation. It requires an Apple Silicon Mac running macOS 14 or
newer.

## Install

```sh
brew tap noisyqubits/noisyqubits
brew install --cask noisyqubits/noisyqubits/filespoke
open -a FileSpoke
```

The first launch opens a short guide. Finder's Shift-drag gesture requires the
macOS Accessibility permission for FileSpoke. Grant it in System Settings →
Privacy & Security → Accessibility, then relaunch FileSpoke. Ordinary drags are
untouched. Turn the gesture off from the FileSpoke menu bar menu at any time.

The first release is ad hoc signed, not Apple notarized. If Gatekeeper asks for
confirmation, use Finder's **Open** command on the app and review its publisher
and source; do not remove macOS quarantine globally.

## Build and verify

The default build fetches seven pinned, checksum-verified media projects and
builds their Apple Silicon/macOS 14 binaries locally. The exact source archives
are mirrored in the [engine source release](https://github.com/NoisyQubits/FileSpoke/releases/tag/engine-sources-v1);
the build verifies their SHA-256 hashes and records the original upstream URLs.
You need Xcode Command Line
Tools, Python 3, CMake, and pkgconf. Meson and Ninja are pinned in
`Tools/media-build-requirements.txt` and installed only into the local build
directory. The installed app needs none of these tools.

```sh
./build.sh
build/FileSpoke.app/Contents/MacOS/FileSpoke --selftest
python3 Tools/package-release.py
```

The selftest checks real PNG-to-PDF, TXT-to-PDF, PDF merge, archive round trip,
and bundled MP3 encoding. The release packager verifies the app signature,
reruns the selftest, and includes source archives matching the bundled engines.
The engine runtime stays private to FileSpoke and supports only local file and
pipe protocols. Source release archives are published beside each app ZIP.

## Project and license

FileSpoke adapts the file-tool work originally developed for
[Vorssaint PR #2258](https://github.com/vorssaint/vorssaint-utils/pull/2258).
The original copyright notices are preserved in the adapted files. The app is
distributed under **GPL-3.0-or-later**. Engine licenses, notices, and the
matching engine sources accompany every release; see the bundled
`MediaEngines/notices` directory and the source archive. `Sources/SystemArchive`
contains public libarchive headers under their included BSD notice.

This is an independent NoisyQubits app. It is not affiliated with Vorssaint or
any other converter. See the source and release notes for supported formats and
known limits.
