#include "frame_buffer_pool.h"

#include <stdlib.h>

void frame_buffer_pool_init(FrameBufferPool* pool) {
	pool->buffers = NULL;
}

void frame_buffer_pool_dispose(FrameBufferPool* pool) {
	FrameBuffer* buffer = pool->buffers;
	while (buffer != NULL) {
		FrameBuffer* next = buffer->next;
		free(buffer->data);
		free(buffer);
		buffer = next;
	}
	pool->buffers = NULL;
}

FrameBuffer* acquire_frame_buffer(FrameBufferPool* pool, int width, int height, HlmediaPixelFormat format, size_t size) {
	FrameBuffer* available = NULL;
	for (FrameBuffer* buffer = pool->buffers; buffer != NULL; buffer = buffer->next) {
		if (buffer->inUse)
			continue;
		if (buffer->width == width && buffer->height == height && buffer->format == format && buffer->capacity >= size) {
			buffer->inUse = true;
			return buffer;
		}
		if (available == NULL)
			available = buffer;
	}

	if (available == NULL) {
		available = (FrameBuffer*)calloc(1, sizeof(FrameBuffer));
		if (available == NULL)
			return NULL;
		available->next = pool->buffers;
		pool->buffers = available;
	}

	if (available->capacity < size) {
		uint8_t* data = (uint8_t*)realloc(available->data, size);
		if (data == NULL)
			return NULL;
		available->data = data;
		available->capacity = size;
	}
	available->width = width;
	available->height = height;
	available->format = format;
	available->inUse = true;
	return available;
}

void release_frame_buffer(FrameBuffer* buffer) {
	if (buffer != NULL)
		buffer->inUse = false;
}
