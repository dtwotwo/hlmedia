#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef enum HlmediaPixelFormat {
	HLMEDIA_PIXEL_FORMAT_NV12 = 0,
	HLMEDIA_PIXEL_FORMAT_YUV420P = 1,
	HLMEDIA_PIXEL_FORMAT_RGBA = 2
} HlmediaPixelFormat;

typedef struct HlmediaFrame {
	double pts;
	int width;
	int height;
	HlmediaPixelFormat format;
	uint8_t* planes[3];
	size_t planeSizes[3];
	int strides[3];
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
