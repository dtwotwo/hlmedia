#pragma once

#define HL_NAME(n) hlmedia_##n

#include <hl.h>

const char* hlmedia_get_distribution(void);
bool hlmedia_is_ffmpeg_static(void);
const char* hlmedia_get_ffmpeg_version(void);
const char* hlmedia_get_ffmpeg_configuration(void);
const char* hlmedia_get_ffmpeg_license(void);

#define _DECODER _ABSTRACT(hlmedia_decoder)
#define _FRAME _ABSTRACT(hlmedia_frame)
#define _AUDIO_CHUNK _ABSTRACT(hlmedia_audio_chunk)
