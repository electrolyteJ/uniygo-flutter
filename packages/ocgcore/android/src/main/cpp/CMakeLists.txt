# ocgcore 源码构建(含 Lua 引擎)。
# ocgcore 的卡牌脚本解释器依赖 Lua 5.3,且以 C++ 符号名引用 Lua API
# (与上游一致)。vendor/lua 以聚合编译单元(C++)并入,见
# src/lua_amalgam.cpp;带 main() 的 lua.c / luac.c 与 onelua.c 不参与编译。
cmake_minimum_required(VERSION 3.13)
project(ocgcore LANGUAGES C CXX)

set(VENDOR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../vendor")

file(GLOB OCG_SOURCES "${VENDOR}/ocgcore/*.cpp")

add_library(ocgcore SHARED
  ${OCG_SOURCES}
  "${CMAKE_CURRENT_SOURCE_DIR}/../../../../src/lua_amalgam.cpp"
)
target_include_directories(ocgcore PRIVATE "${VENDOR}/ocgcore" "${VENDOR}/lua")
target_compile_features(ocgcore PRIVATE cxx_std_17)
