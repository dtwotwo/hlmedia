option(HLMEDIA_WITH_LIBYUV "Enable optional libyuv support" OFF)

set(HLMEDIA_DISTRIBUTION "SHARED" CACHE STRING "hlmedia distribution profile: SHARED or GAME")
set_property(CACHE HLMEDIA_DISTRIBUTION PROPERTY STRINGS SHARED GAME)

set(HLMEDIA_FFMPEG_LINKAGE "SHARED" CACHE STRING "FFmpeg linkage mode: SHARED or STATIC")
set_property(CACHE HLMEDIA_FFMPEG_LINKAGE PROPERTY STRINGS SHARED STATIC)

if(NOT HLMEDIA_DISTRIBUTION MATCHES "^(SHARED|GAME)$")
	message(FATAL_ERROR "Unsupported HLMEDIA_DISTRIBUTION '${HLMEDIA_DISTRIBUTION}'; expected SHARED or GAME")
endif()

if(NOT HLMEDIA_FFMPEG_LINKAGE MATCHES "^(SHARED|STATIC)$")
	message(FATAL_ERROR "Unsupported HLMEDIA_FFMPEG_LINKAGE '${HLMEDIA_FFMPEG_LINKAGE}'; expected SHARED or STATIC")
endif()

if(HLMEDIA_DISTRIBUTION STREQUAL "SHARED" AND NOT HLMEDIA_FFMPEG_LINKAGE STREQUAL "SHARED")
	message(FATAL_ERROR "Distribution SHARED requires FFmpeg linkage SHARED")
elseif(HLMEDIA_DISTRIBUTION STREQUAL "GAME" AND NOT HLMEDIA_FFMPEG_LINKAGE STREQUAL "STATIC")
	message(FATAL_ERROR "Distribution GAME requires FFmpeg linkage STATIC")
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
include(FFmpeg)
hlmedia_find_ffmpeg("${HLMEDIA_FFMPEG_LINKAGE}")

add_library(extension SHARED
	src/hlmedia.c
	src/media_decoder.c
	src/frame_buffer_pool.c
	src/frame_queue.c
	src/audio_queue.c
)

set_target_properties(extension PROPERTIES
	OUTPUT_NAME "hlmedia"
	SUFFIX ".hdll"
)

target_include_directories(extension PRIVATE include)
target_compile_definitions(extension PRIVATE
	HLMEDIA_DISTRIBUTION="${HLMEDIA_DISTRIBUTION}"
)

if(HLMEDIA_FFMPEG_LINKAGE STREQUAL "STATIC")
	target_compile_definitions(extension PRIVATE HLMEDIA_FFMPEG_STATIC=1)
else()
	target_compile_definitions(extension PRIVATE HLMEDIA_FFMPEG_STATIC=0)
endif()

target_link_libraries(extension PRIVATE
	FFmpeg::avformat
	FFmpeg::avcodec
	FFmpeg::avutil
	FFmpeg::swresample
	FFmpeg::swscale
)

if(WIN32)
	if("$ENV{HASHLINK}" STREQUAL "")
		message(FATAL_ERROR "Set HASHLINK to the HashLink SDK root")
	endif()
	target_include_directories(extension PRIVATE "$ENV{HASHLINK}/include")
	target_link_libraries(extension PRIVATE "$ENV{HASHLINK}/libhl.lib")

	if(HLMEDIA_FFMPEG_LINKAGE STREQUAL "STATIC")
		target_link_libraries(extension PRIVATE bcrypt d3d11 d3d12 dxgi dxguid dxva2 ole32 user32)
	endif()
endif()

if(MSVC)
	target_compile_options(extension PRIVATE /wd4244 /wd4267 /wd4996)
endif()

install(TARGETS extension
	RUNTIME DESTINATION .
	LIBRARY DESTINATION .
	ARCHIVE DESTINATION dev
)
