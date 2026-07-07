# Examples

Each example owns its audio backend wrapper and passes it to `VideoPlayer` through `audioSink`.

- `openal` uses `hlopenal`.
- `miniaudio` uses `hlminiaudio`.
- `performance` compares software, hardware, and RGBA fallback video paths.

Create or link `.haxelib` in this directory so all examples use the same local library set.

Place shared FFmpeg DLLs in this directory. Each example build copies runtime DLL/HDLL files from `../native-libs` into the example folder.

Build from the example folder:

```powershell
cd examples/performance
haxe build.hxml
hl performance.hl
```

Examples use `res/video/video.mp4` from this shared `examples` directory. Pass a custom path to the performance example with:

```powershell
hl performance.hl path/to/video.mp4
```

For `miniaudio`, keep `miniaudio.hdll` in `examples/miniaudio`.
