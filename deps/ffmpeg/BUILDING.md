# Rebuilding the game-static FFmpeg SDK

Open an x64 MSVC developer shell, then enter MSYS2 with `make`, `git`, `tar`, and
`xz` installed. Set `FFMPEG_SOURCE`, `FFMPEG_BUILD_DIR`, and
`FFMPEG_INSTALL_DIR`, then run `build-game-static.sh`.

In PowerShell, set `HASHLINK` to a HashLink SDK and relink hlmedia:

```powershell
cmake --preset windows-game-static -DFFMPEG_ROOT="C:/path/to/ffmpeg-install"
cmake --build --preset windows-game-static
cmake --install out/build/windows-game-static --config Release --prefix dist/game-static
dumpbin /DEPENDENTS dist/game-static/hlmedia.hdll
```

The final command must not list avcodec, avformat, avutil, swresample, or
swscale DLLs. The included commit, configure command, generated configuration,
and changes diff identify the exact LGPL-covered build.
