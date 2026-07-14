#!/usr/bin/env bash
set -euo pipefail

: "${FFMPEG_SOURCE:?Set FFMPEG_SOURCE to the pinned FFmpeg source tree}"
: "${FFMPEG_BUILD_DIR:?Set FFMPEG_BUILD_DIR to an out-of-tree build directory}"
: "${FFMPEG_INSTALL_DIR:?Set FFMPEG_INSTALL_DIR to the SDK output directory}"

to_posix_path() {
	if command -v cygpath >/dev/null 2>&1 && [[ "$1" =~ ^[A-Za-z]:[\\/] ]]; then
		cygpath -u "$1"
	else
		printf '%s\n' "$1"
	fi
}

FFMPEG_SOURCE="$(to_posix_path "$FFMPEG_SOURCE")"
FFMPEG_BUILD_DIR="$(to_posix_path "$FFMPEG_BUILD_DIR")"
FFMPEG_INSTALL_DIR="$(to_posix_path "$FFMPEG_INSTALL_DIR")"
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

available_hwaccels="$($FFMPEG_SOURCE/configure --list-hwaccels)"
extra_hwaccel_flags=()
enabled_hwaccels=()
for hwaccel in h264_d3d11va h264_dxva2 h264_d3d12va; do
	if grep -qw "$hwaccel" <<<"$available_hwaccels"; then
		case "$hwaccel" in
			h264_d3d11va) extra_hwaccel_flags+=(--enable-d3d11va) ;;
			h264_dxva2) extra_hwaccel_flags+=(--enable-dxva2) ;;
			h264_d3d12va) extra_hwaccel_flags+=(--enable-d3d12va) ;;
		esac
		extra_hwaccel_flags+=("--enable-hwaccel=$hwaccel")
		enabled_hwaccels+=("$hwaccel")
	fi
done

configure_flags=(
	"--prefix=$FFMPEG_INSTALL_DIR"
	--target-os=win64
	--arch=x64
	--toolchain=msvc
	--extra-cflags=-MD
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
	--enable-d3d11va
	--enable-dxva2
	--enable-d3d12va
	--enable-hwaccel=h264_d3d11va2
	--enable-hwaccel=h264_d3d11va
	--enable-hwaccel=h264_dxva2
	--enable-hwaccel=h264_d3d12va
	"${extra_hwaccel_flags[@]}"
)

printf 'Enabled H.264 hardware accelerators: %s\n' "${enabled_hwaccels[*]:-none}"
printf '%q ' "$FFMPEG_SOURCE/configure" "${configure_flags[@]}" | tee "$FFMPEG_BUILD_DIR/FFMPEG-CONFIGURE.txt"
printf '\n' | tee -a "$FFMPEG_BUILD_DIR/FFMPEG-CONFIGURE.txt"

cd "$FFMPEG_BUILD_DIR"
"$FFMPEG_SOURCE/configure" "${configure_flags[@]}"
compiled_hwaccels=()
for hwaccel in "${enabled_hwaccels[@]}"; do
	component="CONFIG_${hwaccel^^}_HWACCEL"
	if grep -q "^#define $component 1$" config_components.h; then
		compiled_hwaccels+=("$hwaccel")
	fi
done
printf 'Compiled H.264 hardware accelerators: %s\n' "${compiled_hwaccels[*]:-none}"
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
