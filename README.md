# hlmedia

> [!WARNING]
> **This project is still in development.**</br>
> `hlmedia` is currently in an early and unstable state. Some features may be incomplete, broken, or subject to change at any time.</br>
> You can try the latest experimental builds from the **nightly releases**, but expect bugs and rough edges.

`hlmedia` is a HashLink native video playback library for Heaps.

It plays local MP4 files with H.264 video and optional AAC audio. FFmpeg handles
demuxing and decoding, video frames are uploaded to Heaps textures, and audio is
sent to an `AudioSink` supplied by your application. Software-decoded `YUV420P`
and `NV12` frames are uploaded as native planes and converted with a shader;
unsupported formats still use the RGBA fallback path.

Hardware decoding can be requested from Haxe. It is opt-in and falls back to
software by default when the requested backend is unavailable.

At the moment, MP4/H.264 is the only supported video format. Support for more
containers and codecs is planned for future releases.

The library is still early. Use the nightly builds for testing, but expect API
and behavior changes.

## Basic setup

The core library does not choose an audio backend. Without an explicit sink,
`VideoPlayer` uses `NullAudioSink`, so video plays silently. Pass your own
`hlmedia.audio.AudioSink` implementation to route decoded audio to OpenAL,
miniaudio, or another backend.

The OpenAL example uses this setup:

```hxml
-cp .
-cp ../../
-lib heaps
-lib hlsdl
-lib hlopenal
-hl simple.hl
-main Main
-D hlmedia
```

Basic player code:

```haxe
final video = new hlmedia.VideoPlayer({
	loop: true,
	audioSink: new OpenALSink()
});
video.open("res/video/video.mp4");
video.play();

final bitmap = video.createBitmap(s2d);

override function update(dt:Float) {
	video.update(dt);
}
```

Controls such as pause, seek, volume, loop, and callbacks are available on the
same `VideoPlayer` instance:

```haxe
video.pause();
video.play();
video.seek(12.5);
video.setVolume(0.75);
video.setLoop(false);

video.onStart = () -> trace("started");
video.onFinish = () -> trace("finished");
video.onTime(3.5, () -> trace("3.5 seconds"));
```

You can also open a Heaps resource:

```haxe
video.open(hxd.Res.load("video/video.mp4"));
```

## Examples

- `examples/openal` contains an OpenAL `AudioSink` wrapper.
- `examples/miniaudio` contains a miniaudio `AudioSink` wrapper.
- `examples/performance` compares software, hardware, and RGBA fallback paths.

See `examples/README.md` for build notes.

## API overview

`hlmedia.VideoPlayer` is the main class.

- `new(?options)` creates a player.
- `open(pathOrResource)` opens a local file path or `hxd.res.Resource`.
- `play()`, `pause()`, and `stop()` control playback.
- `close()` closes the current video while keeping the player reusable.
- `dispose()` closes the video and releases the player's GPU textures.
- `seek(seconds)` jumps to a position.
- `update(dt)` must be called every frame.
- `createBitmap(s2d)` creates a `VideoBitmap` for normal Heaps 2D rendering.
- `getTexture()` returns the current output texture for custom rendering.
- `getInfo()` returns `VideoInfo` after opening a file.
- `setVolume(value)` clamps volume to `0...1`.
- `setLoop(enabled)` changes loop behavior after construction.
- `setAudioSink(sink)` replaces the audio output implementation.

`VideoBitmap` does not own its player or textures. Remove the bitmap from its
scene before calling `VideoPlayer.dispose()`. Do not reuse a disposed player.

- `onStart`, `onFinish`, and `onTime(seconds, callback)` provide playback callbacks.

Useful state:

- `isPlaying`
- `isPaused`
- `duration`
- `time`
- `droppedFrames`
- `presentedFrames`
- `averageDecodeTimeMs`
- `averageUploadTimeMs`
- `currentVideoQueueSize`
- `hardwareDecodeActive`

Player options:

```haxe
{
	?audioSink: hlmedia.audio.AudioSink,
	?loop: Bool,
	?volume: Float,
	?startPaused: Bool,
	?videoDecodeMode: hlmedia.types.VideoDecodeMode,
	?allowHardwareFallback: Bool,
	?preferNativePixelFormat: Bool
}
```

Decode modes:

```haxe
Software;
HardwareAuto;
HardwareD3D11VA;
HardwareDXVA2;
HardwareVAAPI;
HardwareVideoToolbox;
HardwareCUDA;
HardwareD3D12VA;
```

Defaults:

```haxe
{
	videoDecodeMode: Software,
	allowHardwareFallback: true,
	preferNativePixelFormat: true
}
```

Pixel formats exposed by native frames are in `hlmedia.types.VideoPixelFormat`:
`RGBA`, `YUV420P`, `NV12`, and `P010`. `P010` is reserved for future support.

## Build native library

Requirements:

- HashLink native runtime
- Haxe and Heaps
- FFmpeg development package with:
  - `avformat`
  - `avcodec`
  - `avutil`
  - `swresample`
  - `swscale`

Build with an FFmpeg root directory:

```powershell
cmake -S . -B out/build/default -DFFMPEG_ROOT=C:/ffmpeg
cmake --build out/build/default --config Release
```

Or pass include and library directories separately:

```powershell
cmake -S . -B out/build/default `
  -DFFMPEG_INCLUDE_DIR=C:/ffmpeg/include `
  -DFFMPEG_LIBRARY_DIR=C:/ffmpeg/lib
cmake --build out/build/default --config Release
```

The native output is copied to `native-libs/hlmedia.hdll`.

## Runtime files

Place these files next to your HashLink executable, or make them available on
`PATH`:

- `hlmedia.hdll`
- `avformat-*.dll`
- `avcodec-*.dll`
- `avutil-*.dll`
- `swresample-*.dll`
- `swscale-*.dll`

The examples keep shared runtime files in `examples/`. Each example build runs
`examples/copy-runtime.ps1`, which copies the current `native-libs` runtime files
beside that example's `.hl` output.

Release packages should also include:

- `LICENSE`
- `LICENSE_FFMPEG.md`

The GitHub workflow publishes these files in the `hlmedia-windows` artifact.

## CMake options

- `HLMEDIA_WITH_LIBYUV=ON/OFF`
- `HLMEDIA_BUILD_SHARED=ON`

## FFmpeg license

`hlmedia` is MIT licensed. Release packages include shared FFmpeg DLLs, which
keep their own license terms.

The default workflow uses the BtbN LGPL shared FFmpeg build and copies the DLLs
next to `hlmedia.hdll`. Keep `LICENSE_FFMPEG.md` in every package that ships
FFmpeg DLLs, and check the exact FFmpeg build before distributing it.

Static FFmpeg linking is not supported.

## Video assets

Use MP4/H.264/AAC files. A good default encoding command is documented in
`tools/encode_mp4_h264_aac.md`.

Examples use `examples/res/video/video.mp4` by default.
