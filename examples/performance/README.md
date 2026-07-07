# Performance example

Build from this folder:

```sh
haxe build.hxml
hl performance.hl [path/to/video.mp4]
```

Defaults to `../res/video/video.mp4`.

The build copies the current `hlmedia.hdll` and FFmpeg DLLs beside `performance.hl`.

Keys:

- `1`: software decode
- `2`: hardware auto
- `3`: D3D11VA
- `4`: software decode with RGBA fallback upload
- `5`: VAAPI
- `6`: VideoToolbox
- `7`: CUDA
- `8`: D3D12VA
- `Space`: pause/resume
- `R`: reopen the current file
