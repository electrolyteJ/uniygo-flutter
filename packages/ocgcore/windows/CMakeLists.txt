# Plugin-level CMake configuration for the ocgcore FFI plugin.
#
# The Flutter build system includes this file automatically and collects
# the ${ocgcore_bundled_libraries} list into PLUGIN_BUNDLED_LIBRARIES,
# which is then installed alongside the final binary.

cmake_minimum_required(VERSION 3.14)

# Bundle the appropriate ocgcore.dll for the target architecture.
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
  set(ocgcore_bundled_libraries
    "${CMAKE_CURRENT_SOURCE_DIR}/libs/x64/libocgcore.dll"
    PARENT_SCOPE
  )
else()
  set(ocgcore_bundled_libraries
    "${CMAKE_CURRENT_SOURCE_DIR}/libs/x86/libocgcore.dll"
    PARENT_SCOPE
  )
endif()
