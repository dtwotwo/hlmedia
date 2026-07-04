# Encoding MP4/H.264/AAC assets

Recommended preset:

```bash
ffmpeg -i input.mov \
  -map 0:v:0 -map 0:a:0 \
  -c:v libx264 \
  -pix_fmt yuv420p \
  -profile:v high \
  -level:v 4.1 \
  -preset slow \
  -crf 18 \
  -g 60 \
  -keyint_min 60 \
  -sc_threshold 0 \
  -c:a aac \
  -b:a 160k \
  -ar 48000 \
  -movflags +faststart \
  output.mp4
```

For 60 FPS, use:

```bash
-g 120 -keyint_min 120
```

For faster seeking, use a shorter GOP:

```bash
-g 30
```
