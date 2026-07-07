#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef enum HlmediaPixelFormat {
	HLMEDIA_PIXEL_FORMAT_RGBA = 0,
	HLMEDIA_PIXEL_FORMAT_YUV420P = 1,
	HLMEDIA_PIXEL_FORMAT_NV12 = 2,
	HLMEDIA_PIXEL_FORMAT_P010 = 3
} HlmediaPixelFormat;

typedef enum HlmediaVideoDecodeMode {
	HLMEDIA_VIDEO_DECODE_SOFTWARE = 0,
	HLMEDIA_VIDEO_DECODE_HARDWARE_AUTO = 1,
	HLMEDIA_VIDEO_DECODE_HARDWARE_D3D11VA = 2,
	HLMEDIA_VIDEO_DECODE_HARDWARE_DXVA2 = 3,
	HLMEDIA_VIDEO_DECODE_HARDWARE_VAAPI = 4,
	HLMEDIA_VIDEO_DECODE_HARDWARE_VIDEOTOOLBOX = 5,
	HLMEDIA_VIDEO_DECODE_HARDWARE_CUDA = 6,
	HLMEDIA_VIDEO_DECODE_HARDWARE_D3D12VA = 7
} HlmediaVideoDecodeMode;

typedef struct HlmediaFrame {
	double pts;
	int width;
	int height;
	HlmediaPixelFormat format;
	int planeCount;
	uint8_t* planes[3];
	size_t planeSizes[3];
	int strides[3];
	int planeWidths[3];
	int planeHeights[3];
} HlmediaFrame;

typedef struct HlmediaAudioChunk {
	double pts;
	int frames;
	int channels;
	int sampleRate;
	uint8_t* bytes;
	size_t byteSize;
} HlmediaAudioChunk;

typedef struct HlmediaInfo {
	char* path;
	double duration;
	int width;
	int height;
	double fps;
	char* videoCodec;
	char* audioCodec;
	bool hasAudio;
	int sampleRate;
	int channels;
} HlmediaInfo;
