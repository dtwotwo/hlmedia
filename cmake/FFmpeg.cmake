function(hlmedia_find_ffmpeg linkage)
	if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
		if(linkage STREQUAL "SHARED")
			find_package(PkgConfig REQUIRED)
			foreach(component IN ITEMS avformat avcodec avutil swresample swscale)
				pkg_check_modules(FFMPEG_${component} REQUIRED IMPORTED_TARGET lib${component})
				add_library(FFmpeg::${component} INTERFACE IMPORTED)
				set_property(TARGET FFmpeg::${component} PROPERTY
					INTERFACE_LINK_LIBRARIES PkgConfig::FFMPEG_${component}
				)
			endforeach()
			return()
		endif()
	endif()

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
	if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND linkage STREQUAL "STATIC")
		set(_ffmpeg_library_suffixes "${CMAKE_FIND_LIBRARY_SUFFIXES}")
		set(CMAKE_FIND_LIBRARY_SUFFIXES ".a")
	endif()

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
	if(DEFINED _ffmpeg_library_suffixes)
		set(CMAKE_FIND_LIBRARY_SUFFIXES "${_ffmpeg_library_suffixes}")
	endif()

	if(linkage STREQUAL "SHARED")
		set(FFMPEG_RUNTIME_DIR "${FFMPEG_ROOT}/bin" CACHE PATH "FFmpeg runtime DLL directory" FORCE)
		if(NOT IS_DIRECTORY "${FFMPEG_RUNTIME_DIR}")
			message(FATAL_ERROR "Shared FFmpeg runtime directory was not found at ${FFMPEG_RUNTIME_DIR}")
		endif()
	else()
		foreach(component IN ITEMS avformat avcodec avutil swresample swscale)
			get_filename_component(library_name "${FFMPEG_${component}_LIBRARY}" NAME)
			if(WIN32 AND NOT library_name MATCHES "^(${component}\\.lib|lib${component}\\.a)$")
				message(FATAL_ERROR "Static FFmpeg requires ${component}.lib or lib${component}.a, found ${library_name}")
			elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND NOT library_name STREQUAL "lib${component}.a")
				message(FATAL_ERROR "Static FFmpeg requires lib${component}.a, found ${library_name}")
			endif()
		endforeach()

		if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
			find_package(PkgConfig REQUIRED)
			set(_ffmpeg_pkg_config_path "$ENV{PKG_CONFIG_PATH}")
			set(_ffmpeg_pkg_config_libdir "$ENV{PKG_CONFIG_LIBDIR}")
			set(ENV{PKG_CONFIG_PATH} "${FFMPEG_ROOT}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")
			set(ENV{PKG_CONFIG_LIBDIR} "${FFMPEG_ROOT}/lib/pkgconfig")
			pkg_check_modules(FFMPEG_STATIC REQUIRED libavformat libavcodec libavutil libswresample libswscale)
			set(ENV{PKG_CONFIG_PATH} "${_ffmpeg_pkg_config_path}")
			set(ENV{PKG_CONFIG_LIBDIR} "${_ffmpeg_pkg_config_libdir}")

			set(FFMPEG_SYSTEM_LIBRARIES ${FFMPEG_STATIC_STATIC_LIBRARIES})
			list(REMOVE_ITEM FFMPEG_SYSTEM_LIBRARIES avformat avcodec avutil swresample swscale)
			add_library(FFmpeg::SystemDependencies INTERFACE IMPORTED)
			set_target_properties(FFmpeg::SystemDependencies PROPERTIES
				INTERFACE_LINK_LIBRARIES "${FFMPEG_SYSTEM_LIBRARIES}"
				INTERFACE_LINK_OPTIONS "${FFMPEG_STATIC_STATIC_LDFLAGS_OTHER}"
			)
			set_property(TARGET FFmpeg::avutil APPEND PROPERTY
				INTERFACE_LINK_LIBRARIES FFmpeg::SystemDependencies
			)
		endif()
	endif()
endfunction()
