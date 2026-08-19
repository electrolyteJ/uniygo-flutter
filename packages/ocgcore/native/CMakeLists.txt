# ocgcore 原生共享库构建（Windows DLL；思路同各平台预编译产物）。
#
# 用法（CI / 本地 Windows 均可）：
#   cmake -S packages/ocgcore/native -B packages/ocgcore/native/build -A x64
#   cmake --build packages/ocgcore/native/build --config Release
# 产物：build/Release/ocgcore.dll → 复制到
#   packages/ocgcore/windows/libs/x64/ocgcore.dll（插件打包使用）。
#
# 依赖：vendor/lua（子模块，源码在根目录）+ vendor/ocgcore（16 个 cpp）。
cmake_minimum_required(VERSION 3.20)
project(ocgcore_native CXX)

if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  message(FATAL_ERROR "ocgcore 目前只验证过 64 位构建（-A x64）")
endif()

# ── Lua（静态库）────────────────────────────────────────────────────
# lua.h 没有 extern "C" 保护：必须按 C++ 编译，否则 ocgcore（C++）
# 引用的 mangled lua_* 符号链接不上（同 wasm 构建的经验）。
file(GLOB LUA_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/../vendor/lua/*.c")
list(REMOVE_ITEM LUA_SOURCES
  "${CMAKE_CURRENT_SOURCE_DIR}/../vendor/lua/lua.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/../vendor/lua/luac.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/../vendor/lua/onelua.c"
)
set_source_files_properties(${LUA_SOURCES} PROPERTIES LANGUAGE CXX)
add_library(ocgcore_lua STATIC ${LUA_SOURCES})
target_include_directories(ocgcore_lua PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/../vendor/lua")
if(MSVC)
  # lua 按 C++ 编译后 luaconf 自动走 C++ 异常；关掉 MSVC 的 C 转义告警即可
  target_compile_options(ocgcore_lua PRIVATE /wd4244 /wd4267)
endif()

# ── ocgcore（共享库）────────────────────────────────────────────────
file(GLOB OCGCORE_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/../vendor/ocgcore/*.cpp")
add_library(ocgcore SHARED ${OCGCORE_SOURCES})
target_include_directories(ocgcore PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/../vendor/lua")
# ocgapi.h 的 __declspec(dllexport) 由该宏开启（见 ocgapi.h 头部）
target_compile_definitions(ocgcore PRIVATE OCGCORE_EXPORT_FUNCTIONS)
target_link_libraries(ocgcore PRIVATE ocgcore_lua)
