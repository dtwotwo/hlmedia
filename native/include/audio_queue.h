#pragma once

#include "media_types.h"

#include <stdbool.h>
#include <stddef.h>

typedef struct AudioQueueNode AudioQueueNode;

typedef struct AudioQueue {
	AudioQueueNode* head;
	AudioQueueNode* tail;
	size_t size;
} AudioQueue;

void audio_queue_init(AudioQueue* queue);
void audio_queue_clear(AudioQueue* queue);
bool audio_queue_empty(const AudioQueue* queue);
size_t audio_queue_size(const AudioQueue* queue);
int audio_queue_frame_count(const AudioQueue* queue);
bool audio_queue_push(AudioQueue* queue, HlmediaAudioChunk* chunk);
HlmediaAudioChunk* audio_queue_pop_frames(AudioQueue* queue, int maxFrames);
