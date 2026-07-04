#pragma once

#define HL_NAME(n) hlmedia_##n

#include <hl.h>

#define _DECODER _ABSTRACT(hlmedia_decoder)
#define _FRAME _ABSTRACT(hlmedia_frame)
#define _AUDIO_CHUNK _ABSTRACT(hlmedia_audio_chunk)
