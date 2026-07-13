#!/usr/bin/env bash
set -euo pipefail

: "${FFMPEG_SOURCE:?Set FFMPEG_SOURCE to the source tree used for the build}"
: "${FFMPEG_INSTALL_DIR:?Set FFMPEG_INSTALL_DIR to the built static SDK}"
output="${1:-hlmedia-ffmpeg-game-static-sources.tar.xz}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v cygpath >/dev/null 2>&1; then
	[[ "$FFMPEG_SOURCE" =~ ^[A-Za-z]:[\\/] ]] && FFMPEG_SOURCE="$(cygpath -u "$FFMPEG_SOURCE")"
	[[ "$FFMPEG_INSTALL_DIR" =~ ^[A-Za-z]:[\\/] ]] && FFMPEG_INSTALL_DIR="$(cygpath -u "$FFMPEG_INSTALL_DIR")"
fi
build_info="$FFMPEG_INSTALL_DIR/build-info"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

mkdir -p "$staging/ffmpeg-source"
git -C "$FFMPEG_SOURCE" archive HEAD | tar -x -C "$staging/ffmpeg-source"
cp "$script_dir/build-game-static.sh" "$staging/build-game-static.sh"
cp "$build_info/FFMPEG-COMMIT.txt" "$staging/FFMPEG-COMMIT.txt"
cp "$build_info/FFMPEG-CONFIGURE.txt" "$staging/FFMPEG-CONFIGURE.txt"
cp "$build_info/changes.diff" "$staging/changes.diff"
cp "$build_info/config.h" "$staging/config.h"
cp "$build_info/config_components.h" "$staging/config_components.h"
cp "$build_info/config.mak" "$staging/config.mak"
cp "$build_info/COPYING.LGPLv2.1" "$staging/COPYING.LGPLv2.1"
cp "$build_info/LICENSE.md" "$staging/LICENSE.md"
cp "$script_dir/BUILDING.md" "$staging/BUILDING.md"

if [[ -s "$build_info/changes.diff" ]]; then
	patch -d "$staging/ffmpeg-source" -p1 < "$build_info/changes.diff"
fi

tar -C "$staging" -I 'xz -T0' -cf "$output" \
	ffmpeg-source build-game-static.sh FFMPEG-COMMIT.txt FFMPEG-CONFIGURE.txt \
	changes.diff config.h config_components.h config.mak BUILDING.md \
	COPYING.LGPLv2.1 LICENSE.md
