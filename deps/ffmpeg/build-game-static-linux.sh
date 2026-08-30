#!/usr/bin/env bash
set -euo pipefail

: "${FFMPEG_SOURCE:?Set FFMPEG_SOURCE to the pinned FFmpeg source tree}"
: "${FFMPEG_BUILD_DIR:?Set FFMPEG_BUILD_DIR to an out-of-tree build directory}"
: "${FFMPEG_INSTALL_DIR:?Set FFMPEG_INSTALL_DIR to the SDK output directory}"

FFMPEG_SOURCE="$(cd "$FFMPEG_SOURCE" && pwd)"
mkdir -p "$FFMPEG_BUILD_DIR" "$FFMPEG_INSTALL_DIR"
FFMPEG_BUILD_DIR="$(cd "$FFMPEG_BUILD_DIR" && pwd)"
FFMPEG_INSTALL_DIR="$(cd "$FFMPEG_INSTALL_DIR" && pwd)"

patch_dir="${FFMPEG_PATCH_DIR:-$(dirname "${BASH_SOURCE[0]}")/patches}"
for patch_file in "$patch_dir"/*.patch; do
	[[ -e "$patch_file" ]] || continue
	if git -C "$FFMPEG_SOURCE" apply --check "$patch_file"; then
		git -C "$FFMPEG_SOURCE" apply "$patch_file"
	elif ! git -C "$FFMPEG_SOURCE" apply --reverse --check "$patch_file"; then
		echo "Patch cannot be applied cleanly: $patch_file" >&2
		exit 1
	fi
done

configure_flags=(
	"--prefix=$FFMPEG_INSTALL_DIR"
	--extra-cflags=-fPIC
	--enable-pic
	--disable-inline-asm
	--disable-x86asm
	--disable-programs
	--disable-doc
	--disable-debug
	--disable-network
	--disable-autodetect
	--disable-everything
	--disable-gpl
	--disable-nonfree
	--disable-version3
	--enable-static
	--disable-shared
	--enable-small
	--enable-avcodec
	--enable-avformat
	--enable-avutil
	--enable-swresample
	--enable-swscale
	--disable-avdevice
	--disable-avfilter
	--enable-decoder=h264
	--enable-decoder=aac
	--enable-parser=h264
	--enable-parser=aac
	--enable-demuxer=mov
	--enable-protocol=file
	--enable-vaapi
	--enable-libdrm
	--enable-hwaccel=h264_vaapi
)

printf '%q ' "$FFMPEG_SOURCE/configure" "${configure_flags[@]}" | tee "$FFMPEG_BUILD_DIR/FFMPEG-CONFIGURE.txt"
printf '\n' | tee -a "$FFMPEG_BUILD_DIR/FFMPEG-CONFIGURE.txt"

cd "$FFMPEG_BUILD_DIR"
"$FFMPEG_SOURCE/configure" "${configure_flags[@]}"
make -j"$(nproc)"
make install

build_info="$FFMPEG_INSTALL_DIR/build-info"
mkdir -p "$build_info"
git -C "$FFMPEG_SOURCE" rev-parse HEAD > "$build_info/FFMPEG-COMMIT.txt"
cp "$FFMPEG_BUILD_DIR/FFMPEG-CONFIGURE.txt" "$build_info/FFMPEG-CONFIGURE.txt"
git -C "$FFMPEG_SOURCE" diff --binary > "$build_info/changes.diff"
cp "$FFMPEG_BUILD_DIR/config.h" "$build_info/config.h"
cp "$FFMPEG_BUILD_DIR/config_components.h" "$build_info/config_components.h"
cp "$FFMPEG_BUILD_DIR/ffbuild/config.mak" "$build_info/config.mak"
cp "$FFMPEG_SOURCE/COPYING.LGPLv2.1" "$build_info/COPYING.LGPLv2.1"
cp "$FFMPEG_SOURCE/LICENSE.md" "$build_info/LICENSE.md"
