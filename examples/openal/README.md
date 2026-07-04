# OpenAL Example

This example shows how to provide an OpenAL implementation of `hlmedia.audio.AudioSink`.

Build:

```hxml
haxe build.hxml
```

Run:

```powershell
hl simple.hl
```

`Main.hx` passes `new OpenALSink()` to `VideoPlayer`; the core library does not create the sink.
