set(HASHLINK_ROOT "${HASHLINK_ROOT}" CACHE PATH "HashLink SDK root directory")

set(_hashlink_roots)
foreach(variable IN ITEMS HASHLINK_ROOT HASHLINK HASHLINK_PATH HASHLINKPATH)
	if(DEFINED ${variable} AND NOT "${${variable}}" STREQUAL "")
		list(APPEND _hashlink_roots "${${variable}}")
	endif()
	if(NOT "$ENV{${variable}}" STREQUAL "")
		list(APPEND _hashlink_roots "$ENV{${variable}}")
	endif()
endforeach()

find_program(HASHLINK_EXECUTABLE NAMES hl)
if(HASHLINK_EXECUTABLE)
	get_filename_component(_hashlink_bin_dir "${HASHLINK_EXECUTABLE}" DIRECTORY)
	get_filename_component(_hashlink_bin_parent "${_hashlink_bin_dir}" DIRECTORY)
	list(APPEND _hashlink_roots "${_hashlink_bin_dir}" "${_hashlink_bin_parent}")
endif()

find_path(HASHLINK_INCLUDE_DIR
	NAMES hl.h
	HINTS ${_hashlink_roots}
	PATH_SUFFIXES include
	PATHS /usr/local /usr
)

if(WIN32)
	set(_hashlink_library_names libhl hl)
else()
	set(_hashlink_library_names hl)
endif()

find_library(HASHLINK_LIBRARY
	NAMES ${_hashlink_library_names}
	HINTS ${_hashlink_roots}
	PATH_SUFFIXES lib lib64
	PATHS /usr/local /usr
)

if(NOT HASHLINK_INCLUDE_DIR OR NOT HASHLINK_LIBRARY)
	message(FATAL_ERROR
		"HashLink was not found. Set HASHLINK_ROOT, HASHLINK, HASHLINK_PATH, or HASHLINKPATH "
		"to a HashLink installation, or add HashLink to PATH."
	)
endif()

add_library(HashLink::HashLink UNKNOWN IMPORTED)
set_target_properties(HashLink::HashLink PROPERTIES
	IMPORTED_LOCATION "${HASHLINK_LIBRARY}"
	INTERFACE_INCLUDE_DIRECTORIES "${HASHLINK_INCLUDE_DIR}"
)

mark_as_advanced(HASHLINK_EXECUTABLE HASHLINK_INCLUDE_DIR HASHLINK_LIBRARY)
