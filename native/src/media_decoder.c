#include "media_decoder.h"

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/imgutils.h>
#include <libavutil/log.h>
#include <libavutil/opt.h>
#include <libavutil/pixfmt.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <math.h>

static void media_decoder_configure_logs(void);
static void media_decoder_log_callback(void* ptr, int level, const char* fmt, va_list vl);
static bool media_decoder_open_stream_codecs(MediaDecoder* decoder);
static bool media_decoder_decode_packet(MediaDecoder* decoder, AVPacket* packet);
static bool media_decoder_receive_video_frames(MediaDecoder* decoder);
static bool media_decoder_receive_audio_frames(MediaDecoder* decoder);
static bool media_decoder_queue_video_frame(MediaDecoder* decoder, AVFrame* frame);
static bool media_decoder_queue_audio_frame(MediaDecoder* decoder, AVFrame* frame);
static double media_decoder_packet_time(const MediaDecoder* decoder, int streamIndex, int64_t pts);
static void media_decoder_set_error(MediaDecoder* decoder, const char* message);
static void media_decoder_set_open_error(MediaDecoder* decoder, const char* path, int errorCode);
static void media_decoder_flush_queues(MediaDecoder* decoder);
static void media_info_clear(HlmediaInfo* info);
static char* hlmedia_strdup(const char* value);

MediaDecoder* media_decoder_create(void) {
	media_decoder_configure_logs();

	MediaDecoder* decoder = (MediaDecoder*)calloc(1, sizeof(MediaDecoder));
	if (decoder == NULL)
		return NULL;

	decoder->videoFrame = av_frame_alloc();
	decoder->audioFrame = av_frame_alloc();
	decoder->packet = av_packet_alloc();
	if (decoder->videoFrame == NULL || decoder->audioFrame == NULL || decoder->packet == NULL) {
		media_decoder_destroy(decoder);
		return NULL;
	}
	decoder->videoStream = -1;
	decoder->audioStream = -1;
	decoder->paused = true;
	decoder->info.sampleRate = 48000;
	decoder->info.channels = 2;
	frame_queue_init(&decoder->videoQueue);
	audio_queue_init(&decoder->audioQueue);
	return decoder;
}

static void media_decoder_configure_logs(void) {
	static bool configured = false;
	if (configured)
		return;
	av_log_set_callback(media_decoder_log_callback);
	configured = true;
}

static void media_decoder_log_callback(void* ptr, int level, const char* fmt, va_list vl) {
	if (fmt != NULL && strstr(fmt, "Could not update timestamps for discarded samples") != NULL)
		return;
	av_log_default_callback(ptr, level, fmt, vl);
}

void media_decoder_destroy(MediaDecoder* decoder) {
	if (decoder == NULL)
		return;
	media_decoder_close(decoder);
	av_frame_free(&decoder->videoFrame);
	av_frame_free(&decoder->audioFrame);
	av_packet_free(&decoder->packet);
	free(decoder->lastError);
	free(decoder);
}

bool media_decoder_open(MediaDecoder* decoder, const char* path) {
	media_decoder_close(decoder);
	const char* inputPath = path != NULL ? path : "";
	decoder->info.path = hlmedia_strdup(inputPath);

	const int openResult = avformat_open_input(&decoder->formatContext, inputPath, NULL, NULL);
	if (openResult < 0) {
		media_decoder_set_open_error(decoder, decoder->info.path, openResult);
		return false;
	}
	if (avformat_find_stream_info(decoder->formatContext, NULL) < 0) {
		media_decoder_set_error(decoder, "Failed to read stream info");
		return false;
	}
	if (!media_decoder_open_stream_codecs(decoder))
		return false;

	decoder->info.duration = decoder->formatContext->duration > 0 ? (double)decoder->formatContext->duration / AV_TIME_BASE : 0.0;
	decoder->paused = true;
	decoder->eof = false;
	decoder->audioTrimBefore = 0.0;
	return true;
}

void media_decoder_close(MediaDecoder* decoder) {
	media_decoder_flush_queues(decoder);
	if (decoder->swsContext != NULL) {
		sws_freeContext(decoder->swsContext);
		decoder->swsContext = NULL;
	}
	if (decoder->swrContext != NULL)
		swr_free(&decoder->swrContext);
	if (decoder->videoCodecContext != NULL)
		avcodec_free_context(&decoder->videoCodecContext);
	if (decoder->audioCodecContext != NULL)
		avcodec_free_context(&decoder->audioCodecContext);
	if (decoder->formatContext != NULL)
		avformat_close_input(&decoder->formatContext);
	decoder->videoStream = -1;
	decoder->audioStream = -1;
	decoder->audioTrimBefore = 0.0;
	decoder->eof = false;
	media_info_clear(&decoder->info);
	decoder->info.sampleRate = 48000;
	decoder->info.channels = 2;
}

static bool media_decoder_open_stream_codecs(MediaDecoder* decoder) {
	for (unsigned int i = 0; i < decoder->formatContext->nb_streams; ++i) {
		const AVStream* stream = decoder->formatContext->streams[i];
		const AVCodecParameters* params = stream->codecpar;
		if (params->codec_type == AVMEDIA_TYPE_VIDEO && decoder->videoStream < 0) {
			const AVCodec* codec = avcodec_find_decoder(params->codec_id);
			if (codec == NULL) {
				media_decoder_set_error(decoder, "Unsupported video codec");
				return false;
			}
			decoder->videoCodecContext = avcodec_alloc_context3(codec);
			if (decoder->videoCodecContext == NULL) {
				media_decoder_set_error(decoder, "Failed to allocate video codec context");
				return false;
			}
			if (avcodec_parameters_to_context(decoder->videoCodecContext, params) < 0) {
				media_decoder_set_error(decoder, "Failed to configure video codec");
				avcodec_free_context(&decoder->videoCodecContext);
				return false;
			}
			if (avcodec_open2(decoder->videoCodecContext, codec, NULL) < 0) {
				media_decoder_set_error(decoder, "Failed to open video codec");
				avcodec_free_context(&decoder->videoCodecContext);
				return false;
			}
			decoder->videoStream = (int)i;
			decoder->info.width = decoder->videoCodecContext->width;
			decoder->info.height = decoder->videoCodecContext->height;
			decoder->info.videoCodec = hlmedia_strdup(codec->name != NULL ? codec->name : "");
			const AVRational fps = av_guess_frame_rate(decoder->formatContext, decoder->formatContext->streams[i], NULL);
			decoder->info.fps = fps.den != 0 ? av_q2d(fps) : 0.0;
		} else if (params->codec_type == AVMEDIA_TYPE_AUDIO && decoder->audioStream < 0) {
			const AVCodec* codec = avcodec_find_decoder(params->codec_id);
			if (codec == NULL)
				continue;
			decoder->audioCodecContext = avcodec_alloc_context3(codec);
			if (decoder->audioCodecContext == NULL)
				continue;
			if (avcodec_parameters_to_context(decoder->audioCodecContext, params) < 0) {
				avcodec_free_context(&decoder->audioCodecContext);
				continue;
			}
			if (avcodec_open2(decoder->audioCodecContext, codec, NULL) < 0) {
				avcodec_free_context(&decoder->audioCodecContext);
				continue;
			}
			decoder->audioStream = (int)i;
			decoder->info.hasAudio = true;
			decoder->info.audioCodec = hlmedia_strdup(codec->name != NULL ? codec->name : "");
			decoder->info.sampleRate = 48000;
			decoder->info.channels = 2;
		}
	}

	if (decoder->videoStream < 0) {
		media_decoder_set_error(decoder, "No video stream found");
		return false;
	}
	return true;
}

int media_decoder_decode(MediaDecoder* decoder) {
	if (decoder->formatContext == NULL || decoder->eof || decoder->paused)
		return 0;
	if (frame_queue_size(&decoder->videoQueue) >= 6 && audio_queue_frame_count(&decoder->audioQueue) >= 24000)
		return 1;

	const int read = av_read_frame(decoder->formatContext, decoder->packet);
	if (read < 0) {
		decoder->eof = true;
		if (decoder->videoCodecContext != NULL) {
			avcodec_send_packet(decoder->videoCodecContext, NULL);
			media_decoder_receive_video_frames(decoder);
		}
		return 0;
	}

	const bool ok = media_decoder_decode_packet(decoder, decoder->packet);
	av_packet_unref(decoder->packet);
	return ok ? 1 : -1;
}

static bool media_decoder_decode_packet(MediaDecoder* decoder, AVPacket* packet) {
	if (packet->stream_index == decoder->videoStream) {
		int result = avcodec_send_packet(decoder->videoCodecContext, packet);
		if (result == AVERROR(EAGAIN)) {
			if (!media_decoder_receive_video_frames(decoder))
				return false;
			result = avcodec_send_packet(decoder->videoCodecContext, packet);
		}
		if (result < 0) {
			media_decoder_set_error(decoder, "Failed to send video packet");
			return false;
		}
		return media_decoder_receive_video_frames(decoder);
	}
	if (packet->stream_index == decoder->audioStream && decoder->audioCodecContext != NULL) {
		int result = avcodec_send_packet(decoder->audioCodecContext, packet);
		if (result == AVERROR(EAGAIN)) {
			if (!media_decoder_receive_audio_frames(decoder))
				return false;
			result = avcodec_send_packet(decoder->audioCodecContext, packet);
		}
		if (result < 0) {
			media_decoder_set_error(decoder, "Failed to send audio packet");
			return false;
		}
		return media_decoder_receive_audio_frames(decoder);
	}
	return true;
}

static bool media_decoder_receive_video_frames(MediaDecoder* decoder) {
	for (;;) {
		const int result = avcodec_receive_frame(decoder->videoCodecContext, decoder->videoFrame);
		if (result == AVERROR(EAGAIN) || result == AVERROR_EOF)
			return true;
		if (result < 0) {
			media_decoder_set_error(decoder, "Failed to decode video frame");
			return false;
		}
		if (!media_decoder_queue_video_frame(decoder, decoder->videoFrame)) {
			av_frame_unref(decoder->videoFrame);
			return false;
		}
		av_frame_unref(decoder->videoFrame);
	}
}

static bool media_decoder_receive_audio_frames(MediaDecoder* decoder) {
	for (;;) {
		const int result = avcodec_receive_frame(decoder->audioCodecContext, decoder->audioFrame);
		if (result == AVERROR(EAGAIN) || result == AVERROR_EOF)
			return true;
		if (result < 0) {
			media_decoder_set_error(decoder, "Failed to decode audio frame");
			return false;
		}
		if (!media_decoder_queue_audio_frame(decoder, decoder->audioFrame)) {
			av_frame_unref(decoder->audioFrame);
			return false;
		}
		av_frame_unref(decoder->audioFrame);
	}
}

static bool media_decoder_queue_video_frame(MediaDecoder* decoder, AVFrame* frame) {
	HlmediaFrame out = {0};
	out.pts = frame->best_effort_timestamp == AV_NOPTS_VALUE ? 0.0 : media_decoder_packet_time(decoder, decoder->videoStream, frame->best_effort_timestamp);
	out.width = frame->width;
	out.height = frame->height;
	out.format = HLMEDIA_PIXEL_FORMAT_RGBA;
	if (out.width <= 0 || out.height <= 0 || av_image_check_size((unsigned int)out.width, (unsigned int)out.height, 0, NULL) < 0 || out.width > INT_MAX / 4) {
		media_decoder_set_error(decoder, "Invalid video frame size");
		return false;
	}
	out.strides[0] = out.width * 4;
	if ((size_t)out.height > SIZE_MAX / (size_t)out.strides[0]) {
		media_decoder_set_error(decoder, "Video frame is too large");
		return false;
	}
	out.planeSizes[0] = (size_t)out.strides[0] * (size_t)out.height;
	out.planes[0] = (uint8_t*)malloc(out.planeSizes[0]);
	if (out.planes[0] == NULL) {
		media_decoder_set_error(decoder, "Failed to allocate video frame");
		return false;
	}

	decoder->swsContext = sws_getCachedContext(decoder->swsContext, frame->width, frame->height, (enum AVPixelFormat)frame->format, frame->width, frame->height, AV_PIX_FMT_RGBA, SWS_BILINEAR, NULL, NULL, NULL);
	if (decoder->swsContext == NULL) {
		hlmedia_frame_free(&out);
		media_decoder_set_error(decoder, "Failed to create video scaler");
		return false;
	}

	uint8_t* data[] = {out.planes[0], NULL, NULL, NULL};
	int linesize[] = {out.strides[0], 0, 0, 0};
	sws_scale(decoder->swsContext, (const uint8_t* const*)frame->data, frame->linesize, 0, frame->height, data, linesize);

	if (!frame_queue_push(&decoder->videoQueue, &out)) {
		hlmedia_frame_free(&out);
		media_decoder_set_error(decoder, "Failed to queue video frame");
		return false;
	}
	return true;
}

static bool media_decoder_queue_audio_frame(MediaDecoder* decoder, AVFrame* frame) {
	AVChannelLayout outputLayout;
	av_channel_layout_default(&outputLayout, 2);
	if (decoder->swrContext == NULL) {
		if (swr_alloc_set_opts2(&decoder->swrContext, &outputLayout, AV_SAMPLE_FMT_FLT, 48000, &decoder->audioCodecContext->ch_layout, decoder->audioCodecContext->sample_fmt, decoder->audioCodecContext->sample_rate, 0, NULL) < 0 || swr_init(decoder->swrContext) < 0) {
			media_decoder_set_error(decoder, "Failed to initialize audio resampler");
			if (decoder->swrContext != NULL)
				swr_free(&decoder->swrContext);
			av_channel_layout_uninit(&outputLayout);
			return false;
		}
	}
	av_channel_layout_uninit(&outputLayout);

	if (decoder->audioCodecContext->sample_rate <= 0) {
		media_decoder_set_error(decoder, "Invalid audio sample rate");
		return false;
	}
	const int64_t maxOut64 = av_rescale_rnd(swr_get_delay(decoder->swrContext, decoder->audioCodecContext->sample_rate) + frame->nb_samples, 48000, decoder->audioCodecContext->sample_rate, AV_ROUND_UP);
	if (maxOut64 <= 0 || maxOut64 > INT_MAX || (uint64_t)maxOut64 > SIZE_MAX / (2 * sizeof(float))) {
		media_decoder_set_error(decoder, "Invalid audio frame size");
		return false;
	}
	const int maxOut = (int)maxOut64;
	float* samples = (float*)malloc((size_t)maxOut * 2 * sizeof(float));
	if (samples == NULL) {
		media_decoder_set_error(decoder, "Failed to allocate audio samples");
		return false;
	}

	uint8_t* outData[] = {(uint8_t*)samples};
	const int frames = swr_convert(decoder->swrContext, outData, maxOut, (const uint8_t**)frame->extended_data, frame->nb_samples);
	if (frames < 0) {
		free(samples);
		media_decoder_set_error(decoder, "Failed to resample audio");
		return false;
	}
	if ((size_t)frames > SIZE_MAX / (2 * sizeof(float))) {
		free(samples);
		media_decoder_set_error(decoder, "Audio chunk is too large");
		return false;
	}

	double pts = frame->best_effort_timestamp == AV_NOPTS_VALUE ? 0.0 : media_decoder_packet_time(decoder, decoder->audioStream, frame->best_effort_timestamp);
	int queuedFrames = frames;
	if (pts < decoder->audioTrimBefore) {
		const double trimSeconds = decoder->audioTrimBefore - pts;
		const int trimFrames = (int)ceil(trimSeconds * 48000.0);
		if (trimFrames >= queuedFrames) {
			free(samples);
			return true;
		}
		const size_t trimBytes = (size_t)trimFrames * 2 * sizeof(float);
		const size_t remainingBytes = (size_t)(queuedFrames - trimFrames) * 2 * sizeof(float);
		memmove(samples, (uint8_t*)samples + trimBytes, remainingBytes);
		pts += (double)trimFrames / 48000.0;
		queuedFrames -= trimFrames;
	}
	decoder->audioTrimBefore = 0.0;

	HlmediaAudioChunk chunk = {0};
	chunk.pts = pts;
	chunk.frames = queuedFrames;
	chunk.channels = 2;
	chunk.sampleRate = 48000;
	chunk.byteSize = (size_t)queuedFrames * 2 * sizeof(float);
	chunk.bytes = (uint8_t*)malloc(chunk.byteSize);
	if (chunk.bytes == NULL) {
		free(samples);
		media_decoder_set_error(decoder, "Failed to allocate audio chunk");
		return false;
	}
	memcpy(chunk.bytes, samples, chunk.byteSize);
	free(samples);

	if (!audio_queue_push(&decoder->audioQueue, &chunk)) {
		hlmedia_audio_chunk_free(&chunk);
		media_decoder_set_error(decoder, "Failed to queue audio chunk");
		return false;
	}
	return true;
}

bool media_decoder_seek(MediaDecoder* decoder, double seconds) {
	if (decoder->formatContext == NULL)
		return false;
	const int64_t timestamp = (int64_t)(seconds * AV_TIME_BASE);
	if (av_seek_frame(decoder->formatContext, -1, timestamp, AVSEEK_FLAG_BACKWARD) < 0) {
		media_decoder_set_error(decoder, "Seek failed");
		return false;
	}
	if (decoder->videoCodecContext != NULL)
		avcodec_flush_buffers(decoder->videoCodecContext);
	if (decoder->audioCodecContext != NULL)
		avcodec_flush_buffers(decoder->audioCodecContext);
	if (decoder->swrContext != NULL)
		swr_free(&decoder->swrContext);
	media_decoder_flush_queues(decoder);
	decoder->audioTrimBefore = seconds;
	decoder->eof = false;
	return true;
}

void media_decoder_play(MediaDecoder* decoder) {
	decoder->paused = false;
}

void media_decoder_pause(MediaDecoder* decoder, bool paused) {
	decoder->paused = paused;
}

void media_decoder_stop(MediaDecoder* decoder) {
	media_decoder_seek(decoder, 0.0);
	decoder->paused = true;
}

const HlmediaInfo* media_decoder_get_info(const MediaDecoder* decoder) {
	return &decoder->info;
}

HlmediaFrame* media_decoder_take_video_frame(MediaDecoder* decoder) {
	return frame_queue_pop(&decoder->videoQueue);
}

HlmediaAudioChunk* media_decoder_take_audio_chunk(MediaDecoder* decoder, int maxFrames) {
	if (audio_queue_empty(&decoder->audioQueue))
		return NULL;
	return audio_queue_pop_frames(&decoder->audioQueue, maxFrames);
}

const char* media_decoder_get_last_error(const MediaDecoder* decoder) {
	return decoder->lastError != NULL ? decoder->lastError : "";
}

void hlmedia_frame_free(HlmediaFrame* frame) {
	if (frame == NULL)
		return;
	for (int i = 0; i < 3; ++i) {
		free(frame->planes[i]);
		frame->planes[i] = NULL;
		frame->planeSizes[i] = 0;
	}
}

void hlmedia_audio_chunk_free(HlmediaAudioChunk* chunk) {
	if (chunk == NULL)
		return;
	free(chunk->bytes);
	chunk->bytes = NULL;
	chunk->byteSize = 0;
}

static double media_decoder_packet_time(const MediaDecoder* decoder, int streamIndex, int64_t pts) {
	if (streamIndex < 0 || pts == AV_NOPTS_VALUE)
		return 0.0;
	return (double)pts * av_q2d(decoder->formatContext->streams[streamIndex]->time_base);
}

static void media_decoder_set_error(MediaDecoder* decoder, const char* message) {
	char* next = hlmedia_strdup(message);
	if (next == NULL)
		return;
	free(decoder->lastError);
	decoder->lastError = next;
}

static void media_decoder_set_open_error(MediaDecoder* decoder, const char* path, int errorCode) {
	char error[AV_ERROR_MAX_STRING_SIZE] = {0};
	av_strerror(errorCode, error, sizeof(error));
	const int size = snprintf(NULL, 0, "Failed to open media file '%s': %s", path != NULL ? path : "", error);
	if (size < 0) {
		media_decoder_set_error(decoder, "Failed to open media file");
		return;
	}
	char* message = (char*)malloc((size_t)size + 1);
	if (message == NULL)
		return;
	snprintf(message, (size_t)size + 1, "Failed to open media file '%s': %s", path != NULL ? path : "", error);
	free(decoder->lastError);
	decoder->lastError = message;
}

static void media_decoder_flush_queues(MediaDecoder* decoder) {
	frame_queue_clear(&decoder->videoQueue);
	audio_queue_clear(&decoder->audioQueue);
}

static void media_info_clear(HlmediaInfo* info) {
	free(info->path);
	free(info->videoCodec);
	free(info->audioCodec);
	memset(info, 0, sizeof(*info));
}

static char* hlmedia_strdup(const char* value) {
	const char* text = value != NULL ? value : "";
	const size_t size = strlen(text) + 1;
	char* copy = (char*)malloc(size);
	if (copy != NULL)
		memcpy(copy, text, size);
	return copy;
}
