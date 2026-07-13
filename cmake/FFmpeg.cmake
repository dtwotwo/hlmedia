function(hlmedia_find_ffmpeg linkage)
	set(FFMPEG_ROOT "${FFMPEG_ROOT}" CACHE PATH "FFmpeg SDK root directory")
	if(NOT FFMPEG_ROOT)
		message(FATAL_ERROR "Set FFMPEG_ROOT to an FFmpeg SDK containing include/ and lib/")
	endif()

	set(include_dir "${FFMPEG_ROOT}/include")
	set(lib_dir "${FFMPEG_ROOT}/lib")
	if(NOT EXISTS "${include_dir}/libavcodec/avcodec.h")
		message(FATAL_ERROR "FFmpeg headers were not found under ${include_dir}")
	endif()

	if(DEFINED FFMPEG_RESOLVED_ROOT AND NOT FFMPEG_RESOLVED_ROOT STREQUAL FFMPEG_ROOT)
		foreach(component IN ITEMS avformat avcodec avutil swresample swscale)
			unset(FFMPEG_${component}_LIBRARY CACHE)
		endforeach()
	endif()
	set(FFMPEG_RESOLVED_ROOT "${FFMPEG_ROOT}" CACHE INTERNAL "Resolved FFmpeg SDK root" FORCE)

	foreach(component IN ITEMS avformat avcodec avutil swresample swscale)
		find_library(FFMPEG_${component}_LIBRARY
			NAMES ${component}
			PATHS "${lib_dir}"
			NO_DEFAULT_PATH
		)
		if(NOT FFMPEG_${component}_LIBRARY)
			message(FATAL_ERROR "FFmpeg ${component} library was not found under ${lib_dir}")
		endif()

		add_library(FFmpeg::${component} UNKNOWN IMPORTED)
		set_target_properties(FFmpeg::${component} PROPERTIES
			IMPORTED_LOCATION "${FFMPEG_${component}_LIBRARY}"
			INTERFACE_INCLUDE_DIRECTORIES "${include_dir}"
		)
	endforeach()

	if(linkage STREQUAL "SHARED")
		set(FFMPEG_RUNTIME_DIR "${FFMPEG_ROOT}/bin" CACHE PATH "FFmpeg runtime DLL directory" FORCE)
		if(NOT IS_DIRECTORY "${FFMPEG_RUNTIME_DIR}")
			message(FATAL_ERROR "Shared FFmpeg runtime directory was not found at ${FFMPEG_RUNTIME_DIR}")
		endif()
	else()
		foreach(component IN ITEMS avformat avcodec avutil swresample swscale)
			get_filename_component(library_name "${FFMPEG_${component}_LIBRARY}" NAME)
			if(NOT library_name MATCHES "^(${component}\\.lib|lib${component}\\.a)$")
				message(FATAL_ERROR "Static FFmpeg requires ${component}.lib or lib${component}.a, found ${library_name}")
			endif()
		endforeach()
	endif()
endfunction()
