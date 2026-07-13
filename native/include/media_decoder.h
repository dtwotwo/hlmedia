#pragma once

#include "frame_buffer_pool.h"
#include "audio_queue.h"
#include "frame_queue.h"
#include "media_types.h"

#include <libavutil/hwcontext.h>
#include <libavutil/pixfmt.h>

#include <stdbool.h>
#include <stdint.h>

typedef struct AVFormatContext AVFormatContext;
typedef struct AVCodecContext AVCodecContext;
typedef struct AVFrame AVFrame;
typedef struct AVPacket AVPacket;
typedef struct AVIOContext AVIOContext;
typedef struct AVBufferRef AVBufferRef;
typedef struct SwrContext SwrContext;
typedef struct SwsContext SwsContext;

typedef struct MediaDecoder {
	AVFormatContext* formatContext;
	AVIOContext* avioContext;
	AVCodecContext* videoCodecContext;
	AVCodecContext* audioCodecContext;
	AVFrame* videoFrame;
	AVFrame* audioFrame;
	AVPacket* packet;
	SwrContext* swrContext;
	SwsContext* swsContext;
	AVBufferRef* hwDeviceContext;
	enum AVPixelFormat hwPixelFormat;
	enum AVHWDeviceType hwDeviceType;
	int videoStream;
	int audioStream;
	uint8_t* inputBytes;
	size_t inputSize;
	size_t inputPosition;
	double audioTrimBefore;
	bool eof;
	bool paused;
	bool hwEnabled;
	bool hwAccepted;
	bool allowHardwareFallback;
	bool preferNativePixelFormat;
	HlmediaVideoDecodeMode videoDecodeMode;
	HlmediaInfo info;
	FrameQueue videoQueue;
	FrameBufferPool videoPool;
	AudioQueue audioQueue;
	char* lastError;
} MediaDecoder;

MediaDecoder* media_decoder_create(void);
void media_decoder_destroy(MediaDecoder* decoder);
void media_decoder_set_video_options(MediaDecoder* decoder, HlmediaVideoDecodeMode decodeMode, bool allowHardwareFallback, bool preferNativePixelFormat);
bool media_decoder_open(MediaDecoder* decoder, const char* path);
bool media_decoder_open_bytes(MediaDecoder* decoder, const char* path, const uint8_t* bytes, size_t size);
void media_decoder_close(MediaDecoder* decoder);
int media_decoder_decode(MediaDecoder* decoder);
bool media_decoder_seek(MediaDecoder* decoder, double seconds);
void media_decoder_play(MediaDecoder* decoder);
void media_decoder_pause(MediaDecoder* decoder, bool paused);
void media_decoder_stop(MediaDecoder* decoder);
const HlmediaInfo* media_decoder_get_info(const MediaDecoder* decoder);
HlmediaFrame* media_decoder_take_video_frame(MediaDecoder* decoder);
HlmediaAudioChunk* media_decoder_take_audio_chunk(MediaDecoder* decoder, int maxFrames);
const char* media_decoder_get_last_error(const MediaDecoder* decoder);

void hlmedia_frame_free(HlmediaFrame* frame);
void hlmedia_audio_chunk_free(HlmediaAudioChunk* chunk);
