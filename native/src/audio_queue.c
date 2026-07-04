#include "audio_queue.h"
#include "media_decoder.h"

#include <limits.h>
#include <stdlib.h>
#include <string.h>

struct AudioQueueNode {
	HlmediaAudioChunk chunk;
	struct AudioQueueNode* next;
};

void audio_queue_init(AudioQueue* queue) {
	queue->head = NULL;
	queue->tail = NULL;
	queue->size = 0;
}

void audio_queue_clear(AudioQueue* queue) {
	AudioQueueNode* node = queue->head;
	while (node != NULL) {
		AudioQueueNode* next = node->next;
		hlmedia_audio_chunk_free(&node->chunk);
		free(node);
		node = next;
	}
	audio_queue_init(queue);
}

bool audio_queue_empty(const AudioQueue* queue) {
	return queue->size == 0;
}

size_t audio_queue_size(const AudioQueue* queue) {
	return queue->size;
}

int audio_queue_frame_count(const AudioQueue* queue) {
	int total = 0;
	for (AudioQueueNode* node = queue->head; node != NULL; node = node->next) {
		if (node->chunk.frames > INT_MAX - total)
			return INT_MAX;
		total += node->chunk.frames;
	}
	return total;
}

bool audio_queue_push(AudioQueue* queue, HlmediaAudioChunk* chunk) {
	if (chunk->frames <= 0)
		return true;

	AudioQueueNode* node = (AudioQueueNode*)calloc(1, sizeof(AudioQueueNode));
	if (node == NULL)
		return false;
	node->chunk = *chunk;
	if (queue->tail != NULL)
		queue->tail->next = node;
	else
		queue->head = node;
	queue->tail = node;
	queue->size++;
	return true;
}

HlmediaAudioChunk* audio_queue_pop_frames(AudioQueue* queue, int maxFrames) {
	HlmediaAudioChunk* out = (HlmediaAudioChunk*)calloc(1, sizeof(HlmediaAudioChunk));
	if (out == NULL)
		return NULL;
	out->channels = 2;
	out->sampleRate = 48000;

	while (maxFrames > 0 && queue->head != NULL) {
		HlmediaAudioChunk* chunk = &queue->head->chunk;
		const int frames = maxFrames < chunk->frames ? maxFrames : chunk->frames;
		const int bytesPerFrame = chunk->channels * (int)sizeof(float);
		const size_t byteCount = (size_t)frames * (size_t)bytesPerFrame;
		if (out->byteSize == 0)
			out->pts = chunk->pts;

		if (byteCount > SIZE_MAX - out->byteSize) {
			hlmedia_audio_chunk_free(out);
			free(out);
			return NULL;
		}
		uint8_t* bytes = (uint8_t*)realloc(out->bytes, out->byteSize + byteCount);
		if (bytes == NULL) {
			hlmedia_audio_chunk_free(out);
			free(out);
			return NULL;
		}
		out->bytes = bytes;
		memcpy(out->bytes + out->byteSize, chunk->bytes, byteCount);
		out->byteSize += byteCount;
		out->frames += frames;
		out->channels = chunk->channels;
		out->sampleRate = chunk->sampleRate;
		maxFrames -= frames;

		if (frames == chunk->frames) {
			AudioQueueNode* old = queue->head;
			queue->head = old->next;
			if (queue->head == NULL)
				queue->tail = NULL;
			queue->size--;
			free(chunk->bytes);
			free(old);
		} else {
			const size_t remainingBytes = (size_t)(chunk->frames - frames) * (size_t)bytesPerFrame;
			memmove(chunk->bytes, chunk->bytes + byteCount, remainingBytes);
			uint8_t* resized = (uint8_t*)realloc(chunk->bytes, remainingBytes);
			if (resized != NULL || remainingBytes == 0)
				chunk->bytes = resized;
			chunk->byteSize = remainingBytes;
			chunk->pts += (double)frames / chunk->sampleRate;
			chunk->frames -= frames;
		}
	}

	return out;
}
