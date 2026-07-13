#pragma once

#include "media_types.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct FrameBuffer {
	uint8_t* data;
	size_t capacity;
	int width;
	int height;
	HlmediaPixelFormat format;
	bool inUse;
	struct FrameBuffer* next;
} FrameBuffer;

typedef struct FrameBufferPool {
	FrameBuffer* buffers;
} FrameBufferPool;

void frame_buffer_pool_init(FrameBufferPool* pool);
void frame_buffer_pool_dispose(FrameBufferPool* pool);
FrameBuffer* acquire_frame_buffer(FrameBufferPool* pool, int width, int height, HlmediaPixelFormat format, size_t size);
void release_frame_buffer(FrameBuffer* buffer);
