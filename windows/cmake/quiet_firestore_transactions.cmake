# Compile a local copy so pub-cache and other projects are left untouched.
function(campushub_quiet_firestore_transactions)
  if(NOT TARGET cloud_firestore_plugin)
    return()
  endif()

  get_target_property(plugin_dir cloud_firestore_plugin SOURCE_DIR)
  set(original_source "${plugin_dir}/cloud_firestore_plugin.cpp")
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${original_source}")
  file(READ "${original_source}" plugin_source)

  # Match only the upstream Before/After and transaction operation prints.
  # Keep stderr and all actual Firestore error handling intact.
  string(REGEX REPLACE
    "std::cout[ \t\r\n]*<<[ \t\r\n]*\"(Before: |After: |Transaction (set|update|delete))\"[^;]*;[^\n]*"
    "" quiet_source "${plugin_source}")

  if(quiet_source STREQUAL plugin_source)
    return()
  endif()

  set(output_dir "${CMAKE_CURRENT_BINARY_DIR}/quiet_firestore")
  file(MAKE_DIRECTORY "${output_dir}")
  set(patched_source "${output_dir}/cloud_firestore_plugin.cpp")
  # configure_file tracks the original and only rewrites changed output.
  set(quiet_source_file "${output_dir}/cloud_firestore_plugin.cpp.in")
  file(WRITE "${quiet_source_file}" "${quiet_source}")
  configure_file("${quiet_source_file}" "${patched_source}" COPYONLY)

  get_target_property(plugin_sources cloud_firestore_plugin SOURCES)
  set(patched_sources)
  foreach(source IN LISTS plugin_sources)
    get_filename_component(source_name "${source}" NAME)
    if(source_name STREQUAL "cloud_firestore_plugin.cpp")
      list(APPEND patched_sources "${patched_source}")
    else()
      list(APPEND patched_sources "${source}")
    endif()
  endforeach()
  set_property(TARGET cloud_firestore_plugin PROPERTY SOURCES "${patched_sources}")
  target_include_directories(cloud_firestore_plugin PRIVATE "${plugin_dir}")
endfunction()
