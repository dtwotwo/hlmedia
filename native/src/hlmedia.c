#include "hlmedia.h"
#include "media_decoder.h"

#include <limits.h>
#include <stdlib.h>
#include <string.h>

static char* globalLastError;

static bool size_fits_hl_bytes(size_t size) {
	return size <= INT_MAX;
}

static char* copy_c_string(const char* value) {
	const char* text = value != NULL ? value : "";
	const size_t size = strlen(text) + 1;
	char* copy = (char*)malloc(size);
	if (copy != NULL)
		memcpy(copy, text, size);
	return copy;
}

HL_PRIM MediaDecoder* HL_NAME(open)(vbyte* path) {
	MediaDecoder* decoder = media_decoder_create();
	if (decoder == NULL)
		return NULL;
	if (!media_decoder_open(decoder, (const char*)path)) {
		free(globalLastError);
		globalLastError = copy_c_string(media_decoder_get_last_error(decoder));
		media_decoder_destroy(decoder);
		return NULL;
	}
	return decoder;
}

HL_PRIM MediaDecoder* HL_NAME(open_with_options)(vbyte* path, int decodeMode, bool allowHardwareFallback, bool preferNativePixelFormat) {
	MediaDecoder* decoder = media_decoder_create();
	if (decoder == NULL)
		return NULL;
	media_decoder_set_video_options(decoder, (HlmediaVideoDecodeMode)decodeMode, allowHardwareFallback, preferNativePixelFormat);
	if (!media_decoder_open(decoder, (const char*)path)) {
		free(globalLastError);
		globalLastError = copy_c_string(media_decoder_get_last_error(decoder));
		media_decoder_destroy(decoder);
		return NULL;
	}
	return decoder;
}

HL_PRIM MediaDecoder* HL_NAME(open_bytes)(vbyte* path, vbyte* bytes, int size) {
	MediaDecoder* decoder = media_decoder_create();
	if (decoder == NULL)
		return NULL;
	if (size < 0 || !media_decoder_open_bytes(decoder, (const char*)path, (const uint8_t*)bytes, (size_t)size)) {
		free(globalLastError);
		globalLastError = copy_c_string(media_decoder_get_last_error(decoder));
		media_decoder_destroy(decoder);
		return NULL;
	}
	return decoder;
}

HL_PRIM MediaDecoder* HL_NAME(open_bytes_with_options)(vbyte* path, vbyte* bytes, int size, int decodeMode, bool allowHardwareFallback, bool preferNativePixelFormat) {
	MediaDecoder* decoder = media_decoder_create();
	if (decoder == NULL)
		return NULL;
	media_decoder_set_video_options(decoder, (HlmediaVideoDecodeMode)decodeMode, allowHardwareFallback, preferNativePixelFormat);
	if (size < 0 || !media_decoder_open_bytes(decoder, (const char*)path, (const uint8_t*)bytes, (size_t)size)) {
		free(globalLastError);
		globalLastError = copy_c_string(media_decoder_get_last_error(decoder));
		media_decoder_destroy(decoder);
		return NULL;
	}
	return decoder;
}

HL_PRIM void HL_NAME(close)(MediaDecoder* decoder) {
	media_decoder_destroy(decoder);
}

HL_PRIM int HL_NAME(decode)(MediaDecoder* decoder) {
	return decoder == NULL ? 0 : media_decoder_decode(decoder);
}

HL_PRIM void HL_NAME(play)(MediaDecoder* decoder) {
	if (decoder != NULL)
		media_decoder_play(decoder);
}

HL_PRIM void HL_NAME(pause)(MediaDecoder* decoder, bool paused) {
	if (decoder != NULL)
		media_decoder_pause(decoder, paused);
}

HL_PRIM void HL_NAME(stop)(MediaDecoder* decoder) {
	if (decoder != NULL)
		media_decoder_stop(decoder);
}

HL_PRIM bool HL_NAME(seek)(MediaDecoder* decoder, double seconds) {
	if (decoder == NULL)
		return false;
	const bool ok = media_decoder_seek(decoder, seconds);
	if (!ok) {
		free(globalLastError);
		globalLastError = copy_c_string(media_decoder_get_last_error(decoder));
	}
	return ok;
}

HL_PRIM double HL_NAME(duration)(MediaDecoder* decoder) {
	return decoder == NULL ? 0.0 : media_decoder_get_info(decoder)->duration;
}

HL_PRIM int HL_NAME(width)(MediaDecoder* decoder) {
	return decoder == NULL ? 0 : media_decoder_get_info(decoder)->width;
}

HL_PRIM int HL_NAME(height)(MediaDecoder* decoder) {
	return decoder == NULL ? 0 : media_decoder_get_info(decoder)->height;
}

HL_PRIM double HL_NAME(fps)(MediaDecoder* decoder) {
	return decoder == NULL ? 0.0 : media_decoder_get_info(decoder)->fps;
}

HL_PRIM bool HL_NAME(has_audio)(MediaDecoder* decoder) {
	return decoder != NULL && media_decoder_get_info(decoder)->hasAudio;
}

HL_PRIM bool HL_NAME(hardware_decode_active)(MediaDecoder* decoder) {
	return decoder != NULL && decoder->hwEnabled && decoder->hwAccepted;
}

HL_PRIM int HL_NAME(video_queue_size)(MediaDecoder* decoder) {
	return decoder == NULL ? 0 : (int)frame_queue_size(&decoder->videoQueue);
}

HL_PRIM int HL_NAME(audio_queue_frames)(MediaDecoder* decoder) {
	return decoder == NULL ? 0 : audio_queue_frame_count(&decoder->audioQueue);
}

HL_PRIM bool HL_NAME(eof)(MediaDecoder* decoder) {
	return decoder != NULL && decoder->eof;
}

HL_PRIM int HL_NAME(sample_rate)(MediaDecoder* decoder) {
	return decoder == NULL ? 48000 : media_decoder_get_info(decoder)->sampleRate;
}

HL_PRIM int HL_NAME(channels)(MediaDecoder* decoder) {
	return decoder == NULL ? 2 : media_decoder_get_info(decoder)->channels;
}

static vbyte* copy_string(const char* value) {
	const char* text = value != NULL ? value : "";
	const size_t size = strlen(text) + 1;
	return size_fits_hl_bytes(size) ? hl_copy_bytes((const vbyte*)text, (int)size) : NULL;
}

HL_PRIM vbyte* HL_NAME(video_codec)(MediaDecoder* decoder) {
	return copy_string(decoder == NULL ? "" : media_decoder_get_info(decoder)->videoCodec);
}

HL_PRIM vbyte* HL_NAME(audio_codec)(MediaDecoder* decoder) {
	return copy_string(decoder == NULL ? "" : media_decoder_get_info(decoder)->audioCodec);
}

HL_PRIM vbyte* HL_NAME(hardware_decode_backend)(MediaDecoder* decoder) {
	if (decoder == NULL || !decoder->hwEnabled || !decoder->hwAccepted)
		return copy_string("");
	return copy_string(av_hwdevice_get_type_name(decoder->hwDeviceType));
}

HL_PRIM vbyte* HL_NAME(last_error)() {
	return copy_string(globalLastError);
}

HL_PRIM HlmediaFrame* HL_NAME(get_video_frame)(MediaDecoder* decoder) {
	return decoder == NULL ? NULL : media_decoder_take_video_frame(decoder);
}

HL_PRIM void HL_NAME(release_video_frame)(MediaDecoder* decoder, HlmediaFrame* frame) {
	(void)decoder;
	if (frame == NULL)
		return;
	hlmedia_frame_free(frame);
	free(frame);
}

HL_PRIM double HL_NAME(frame_pts)(HlmediaFrame* frame) {
	return frame == NULL ? 0.0 : frame->pts;
}

HL_PRIM int HL_NAME(frame_format)(HlmediaFrame* frame) {
	return frame == NULL ? 0 : (int)frame->format;
}

HL_PRIM int HL_NAME(frame_width)(HlmediaFrame* frame) {
	return frame == NULL ? 0 : frame->width;
}

HL_PRIM int HL_NAME(frame_height)(HlmediaFrame* frame) {
	return frame == NULL ? 0 : frame->height;
}

HL_PRIM int HL_NAME(frame_plane_count)(HlmediaFrame* frame) {
	return frame == NULL ? 0 : frame->planeCount;
}

HL_PRIM int HL_NAME(frame_plane_width)(HlmediaFrame* frame, int plane) {
	return frame == NULL || plane < 0 || plane > 2 ? 0 : frame->planeWidths[plane];
}

HL_PRIM int HL_NAME(frame_plane_height)(HlmediaFrame* frame, int plane) {
	return frame == NULL || plane < 0 || plane > 2 ? 0 : frame->planeHeights[plane];
}

HL_PRIM int HL_NAME(frame_stride)(HlmediaFrame* frame, int plane) {
	return frame == NULL || plane < 0 || plane > 2 ? 0 : frame->strides[plane];
}

HL_PRIM int HL_NAME(frame_plane_size)(HlmediaFrame* frame, int plane) {
	return frame == NULL || plane < 0 || plane > 2 || !size_fits_hl_bytes(frame->planeSizes[plane]) ? 0 : (int)frame->planeSizes[plane];
}

HL_PRIM vbyte* HL_NAME(frame_plane)(HlmediaFrame* frame, int plane) {
	if (frame == NULL || plane < 0 || plane > 2 || frame->planeSizes[plane] == 0 || !size_fits_hl_bytes(frame->planeSizes[plane]))
		return NULL;
	return (vbyte*)frame->planes[plane];
}

HL_PRIM HlmediaAudioChunk* HL_NAME(get_audio_samples)(MediaDecoder* decoder, int maxFrames) {
	return decoder == NULL ? NULL : media_decoder_take_audio_chunk(decoder, maxFrames);
}

HL_PRIM void HL_NAME(release_audio_samples)(MediaDecoder* decoder, HlmediaAudioChunk* chunk) {
	(void)decoder;
	if (chunk == NULL)
		return;
	hlmedia_audio_chunk_free(chunk);
	free(chunk);
}

HL_PRIM int HL_NAME(audio_chunk_frames)(HlmediaAudioChunk* chunk) {
	return chunk == NULL ? 0 : chunk->frames;
}

HL_PRIM int HL_NAME(audio_chunk_size)(HlmediaAudioChunk* chunk) {
	return chunk == NULL || !size_fits_hl_bytes(chunk->byteSize) ? 0 : (int)chunk->byteSize;
}

HL_PRIM vbyte* HL_NAME(audio_chunk_bytes)(HlmediaAudioChunk* chunk) {
	if (chunk == NULL || chunk->byteSize == 0 || !size_fits_hl_bytes(chunk->byteSize))
		return NULL;
	return hl_copy_bytes((const vbyte*)chunk->bytes, (int)chunk->byteSize);
}

DEFINE_PRIM(_DECODER, open, _BYTES);
DEFINE_PRIM(_DECODER, open_with_options, _BYTES _I32 _BOOL _BOOL);
DEFINE_PRIM(_DECODER, open_bytes, _BYTES _BYTES _I32);
DEFINE_PRIM(_DECODER, open_bytes_with_options, _BYTES _BYTES _I32 _I32 _BOOL _BOOL);
DEFINE_PRIM(_VOID, close, _DECODER);
DEFINE_PRIM(_I32, decode, _DECODER);
DEFINE_PRIM(_VOID, play, _DECODER);
DEFINE_PRIM(_VOID, pause, _DECODER _BOOL);
DEFINE_PRIM(_VOID, stop, _DECODER);
DEFINE_PRIM(_BOOL, seek, _DECODER _F64);
DEFINE_PRIM(_F64, duration, _DECODER);
DEFINE_PRIM(_I32, width, _DECODER);
DEFINE_PRIM(_I32, height, _DECODER);
DEFINE_PRIM(_F64, fps, _DECODER);
DEFINE_PRIM(_BOOL, has_audio, _DECODER);
DEFINE_PRIM(_BOOL, hardware_decode_active, _DECODER);
DEFINE_PRIM(_I32, video_queue_size, _DECODER);
DEFINE_PRIM(_I32, audio_queue_frames, _DECODER);
DEFINE_PRIM(_BOOL, eof, _DECODER);
DEFINE_PRIM(_I32, sample_rate, _DECODER);
DEFINE_PRIM(_I32, channels, _DECODER);
DEFINE_PRIM(_BYTES, video_codec, _DECODER);
DEFINE_PRIM(_BYTES, audio_codec, _DECODER);
DEFINE_PRIM(_BYTES, hardware_decode_backend, _DECODER);
DEFINE_PRIM(_BYTES, last_error, _NO_ARG);
DEFINE_PRIM(_FRAME, get_video_frame, _DECODER);
DEFINE_PRIM(_VOID, release_video_frame, _DECODER _FRAME);
DEFINE_PRIM(_F64, frame_pts, _FRAME);
DEFINE_PRIM(_I32, frame_format, _FRAME);
DEFINE_PRIM(_I32, frame_width, _FRAME);
DEFINE_PRIM(_I32, frame_height, _FRAME);
DEFINE_PRIM(_I32, frame_plane_count, _FRAME);
DEFINE_PRIM(_I32, frame_plane_width, _FRAME _I32);
DEFINE_PRIM(_I32, frame_plane_height, _FRAME _I32);
DEFINE_PRIM(_I32, frame_stride, _FRAME _I32);
DEFINE_PRIM(_I32, frame_plane_size, _FRAME _I32);
DEFINE_PRIM(_BYTES, frame_plane, _FRAME _I32);
DEFINE_PRIM(_AUDIO_CHUNK, get_audio_samples, _DECODER _I32);
DEFINE_PRIM(_VOID, release_audio_samples, _DECODER _AUDIO_CHUNK);
DEFINE_PRIM(_I32, audio_chunk_frames, _AUDIO_CHUNK);
DEFINE_PRIM(_I32, audio_chunk_size, _AUDIO_CHUNK);
DEFINE_PRIM(_BYTES, audio_chunk_bytes, _AUDIO_CHUNK);
