# FFmpeg licensing and source

hlmedia uses FFmpeg under the GNU Lesser General Public License version 2.1 or
later. FFmpeg also contains files under compatible permissive licenses. The
exact license reported by each binary is available through
`NativeMedia.buildInfo()`.

## Shared distribution

`hlmedia-windows-shared-x64.zip` contains an LGPL-compatible shared FFmpeg SDK.
The FFmpeg DLLs remain separately replaceable. `BUILD_INFO.txt` identifies the
SDK used for the release.

## Game static distribution

`hlmedia-windows-game-static-x64.zip` statically links the pinned minimal FFmpeg
build. Its configuration explicitly disables GPL, nonfree, and version 3 code,
and does not enable libx264, libx265, or other external codec libraries. The
archive includes `FFMPEG-COMMIT.txt`, `FFMPEG-CONFIGURE.txt`,
`COPYING.LGPLv2.1`, and FFmpeg's `LICENSE.md`.

`deps/ffmpeg/create-source-package.sh` generates a package containing the exact
FFmpeg source revision, local changes, generated configuration, builder, and
rebuilding instructions needed to rebuild the static SDK and relink
`hlmedia.hdll`. The pinned revision is recorded in `deps/ffmpeg/VERSION`.

You may replace or modify the LGPL-covered FFmpeg code by rebuilding that source
package and relinking hlmedia as described in its `BUILDING.md`.
