#include "frame_queue.h"
#include "media_decoder.h"

#include <stdlib.h>

struct FrameQueueNode {
	HlmediaFrame frame;
	struct FrameQueueNode* next;
};

void frame_queue_init(FrameQueue* queue) {
	queue->head = NULL;
	queue->tail = NULL;
	queue->size = 0;
}

void frame_queue_clear(FrameQueue* queue) {
	FrameQueueNode* node = queue->head;
	while (node != NULL) {
		FrameQueueNode* next = node->next;
		hlmedia_frame_free(&node->frame);
		free(node);
		node = next;
	}
	frame_queue_init(queue);
}

bool frame_queue_empty(const FrameQueue* queue) {
	return queue->size == 0;
}

size_t frame_queue_size(const FrameQueue* queue) {
	return queue->size;
}

bool frame_queue_push(FrameQueue* queue, HlmediaFrame* frame) {
	FrameQueueNode* node = (FrameQueueNode*)calloc(1, sizeof(FrameQueueNode));
	if (node == NULL)
		return false;
	node->frame = *frame;
	if (queue->tail != NULL)
		queue->tail->next = node;
	else
		queue->head = node;
	queue->tail = node;
	queue->size++;
	return true;
}

HlmediaFrame* frame_queue_pop(FrameQueue* queue) {
	if (queue->head == NULL)
		return NULL;

	FrameQueueNode* node = queue->head;
	HlmediaFrame* frame = (HlmediaFrame*)malloc(sizeof(HlmediaFrame));
	if (frame == NULL)
		return NULL;

	*frame = node->frame;
	queue->head = node->next;
	if (queue->head == NULL)
		queue->tail = NULL;
	queue->size--;
	free(node);
	return frame;
}
