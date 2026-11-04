# Fetch AppImage tooling (appimagetool, linuxdeploy, linuxdeploy-plugin-qt)
# into a local directory and write an environment snippet with PATH updates.
#
# Usage (inside the build container, from the Audacity source root):
#   cmake -DTOOLS_ROOT=/src/build-appimage/_appimage_tools \
#         -DENV_OUT=/src/build-appimage/appimage-tools-env.sh \
#         -P /src/../build-env/cmake/fetch_appimage_tools.cmake
#
# When run via package-appimage.sh, SRC_ROOT and BUILD_ENV_DIR are set explicitly.

cmake_minimum_required(VERSION 3.21)

if(NOT SRC_ROOT)
    get_filename_component(SRC_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../audacity-4.0.2" ABSOLUTE)
endif()
if(NOT TOOLS_ROOT)
    set(TOOLS_ROOT "${SRC_ROOT}/build-appimage/_appimage_tools")
endif()
if(NOT ENV_OUT)
    set(ENV_OUT "${SRC_ROOT}/build-appimage/appimage-tools-env.sh")
endif()

set(LOCAL_ROOT_PATH "${TOOLS_ROOT}")
include("${SRC_ROOT}/muse_deps/buildtools/manifest.cmake")

require_tool(appimagetool)
require_tool(linuxdeploy)
require_tool(linuxdeploy-plugin-qt)

set(_path_prefix "")
foreach(_tool appimagetool linuxdeploy linuxdeploy-plugin-qt)
    get_property(_bin_dir GLOBAL PROPERTY ${_tool}_BIN_DIR)
    if(_bin_dir)
        set(_path_prefix "${_bin_dir}:${_path_prefix}")
        message(STATUS "tool ${_tool} => ${_bin_dir}")
    else()
        message(FATAL_ERROR "tool ${_tool} did not publish a BIN_DIR")
    endif()
endforeach()

get_filename_component(_env_dir "${ENV_OUT}" DIRECTORY)
file(MAKE_DIRECTORY "${_env_dir}")
file(WRITE "${ENV_OUT}" "export PATH=\"${_path_prefix}$PATH\"\n")
message(STATUS "Wrote ${ENV_OUT}")
