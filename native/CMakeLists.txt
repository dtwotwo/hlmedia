option(HLMEDIA_WITH_LIBYUV "Enable optional libyuv support" OFF)
option(HLMEDIA_BUILD_SHARED "Build hlmedia as a shared HashLink extension" ON)

set(FFMPEG_ROOT "" CACHE PATH "FFmpeg root directory")
set(FFMPEG_INCLUDE_DIR "" CACHE PATH "FFmpeg include directory")
set(FFMPEG_LIBRARY_DIR "" CACHE PATH "FFmpeg library directory")

if(FFMPEG_ROOT)
	set(FFMPEG_INCLUDE_DIR "${FFMPEG_ROOT}/include" CACHE PATH "" FORCE)
	set(FFMPEG_LIBRARY_DIR "${FFMPEG_ROOT}/lib" CACHE PATH "" FORCE)
endif()

if(NOT FFMPEG_INCLUDE_DIR OR NOT FFMPEG_LIBRARY_DIR)
	message(FATAL_ERROR "Set FFMPEG_ROOT or both FFMPEG_INCLUDE_DIR and FFMPEG_LIBRARY_DIR")
endif()

add_library(extension SHARED
	src/hlmedia.c
	src/media_decoder.c
	src/frame_queue.c
	src/audio_queue.c
)

set_target_properties(extension PROPERTIES
	OUTPUT_NAME "hlmedia"
	SUFFIX ".hdll"
)

target_include_directories(extension PRIVATE
	include
	"${FFMPEG_INCLUDE_DIR}"
)

if(WIN32)
	target_include_directories(extension PRIVATE "$ENV{HASHLINK}/include")
	target_link_directories(extension PRIVATE "$ENV{HASHLINK}" "${FFMPEG_LIBRARY_DIR}")
	target_link_libraries(extension PRIVATE
		"$ENV{HASHLINK}/libhl.lib"
		avformat
		avcodec
		avutil
		swresample
		swscale
	)
else()
	target_link_directories(extension PRIVATE "${FFMPEG_LIBRARY_DIR}")
	target_link_libraries(extension PRIVATE avformat avcodec avutil swresample swscale)
endif()

if(MSVC)
	target_compile_options(extension PRIVATE /wd4244 /wd4267 /wd4996)
endif()

set(HLMEDIA_HDLL_DIR "${CMAKE_SOURCE_DIR}/native-libs/hdll")

add_custom_command(TARGET extension POST_BUILD
	COMMAND "${CMAKE_COMMAND}" -E make_directory "${HLMEDIA_HDLL_DIR}"
	COMMAND "${CMAKE_COMMAND}" -E copy_if_different "$<TARGET_FILE:extension>" "${HLMEDIA_HDLL_DIR}/$<TARGET_FILE_NAME:extension>"
)

if(WIN32)
	get_filename_component(FFMPEG_BIN_DIR "${FFMPEG_LIBRARY_DIR}/../bin" ABSOLUTE)
	file(GLOB HLMEDIA_FFMPEG_DLLS CONFIGURE_DEPENDS
		"${FFMPEG_BIN_DIR}/avcodec-*.dll"
		"${FFMPEG_BIN_DIR}/avformat-*.dll"
		"${FFMPEG_BIN_DIR}/avutil-*.dll"
		"${FFMPEG_BIN_DIR}/swresample-*.dll"
		"${FFMPEG_BIN_DIR}/swscale-*.dll"
	)
	if(HLMEDIA_FFMPEG_DLLS)
		add_custom_command(TARGET extension POST_BUILD
			COMMAND "${CMAKE_COMMAND}" -E copy_if_different ${HLMEDIA_FFMPEG_DLLS} "${HLMEDIA_HDLL_DIR}"
		)
	endif()
endif()
