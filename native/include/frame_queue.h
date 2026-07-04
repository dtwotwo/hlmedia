#pragma once

#include "media_types.h"

#include <stdbool.h>
#include <stddef.h>

typedef struct FrameQueueNode FrameQueueNode;

typedef struct FrameQueue {
	FrameQueueNode* head;
	FrameQueueNode* tail;
	size_t size;
} FrameQueue;

void frame_queue_init(FrameQueue* queue);
void frame_queue_clear(FrameQueue* queue);
bool frame_queue_empty(const FrameQueue* queue);
size_t frame_queue_size(const FrameQueue* queue);
bool frame_queue_push(FrameQueue* queue, HlmediaFrame* frame);
HlmediaFrame* frame_queue_pop(FrameQueue* queue);
