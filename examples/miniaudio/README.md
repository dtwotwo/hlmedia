# Miniaudio Example

This example shows how to provide a miniaudio implementation of `hlmedia.audio.AudioSink`.

Add `miniaudio.hdll` to get working `hlminiaudio`.

Then build the example:

```hxml
haxe build.hxml
```

Run:

```powershell
hl simple.hl
```

`Main.hx` initializes `hlminiaudio`, passes `new MiniAudioSink()` to `VideoPlayer`, and updates the miniaudio engine every frame.
