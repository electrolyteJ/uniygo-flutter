// Lua 5.3 聚合编译单元。
//
// ocgcore 的 C++ 代码以 C++ 符号名引用 Lua API(与上游 ygopro-core 一致:
// 上游 premake 即将 Lua 以 C++ 编译,产物中 lua 符号为 C++ 修饰名)。
// 若 Lua 按 C 编译,链接时会出现大量 extern "C" 符号缺失。因此将全部
// Lua 源文件以 C++ 方式并入本编译单元,排除带 main() 的 lua.c / luac.c
// 与官方聚合文件 onelua.c。

#include "../vendor/lua/lapi.c"
#include "../vendor/lua/lauxlib.c"
#include "../vendor/lua/lbaselib.c"
#include "../vendor/lua/lbitlib.c"
#include "../vendor/lua/lcode.c"
#include "../vendor/lua/lcorolib.c"
#include "../vendor/lua/lctype.c"
#include "../vendor/lua/ldblib.c"
#include "../vendor/lua/ldebug.c"
#include "../vendor/lua/ldo.c"
#include "../vendor/lua/ldump.c"
#include "../vendor/lua/lfunc.c"
#include "../vendor/lua/lgc.c"
#include "../vendor/lua/linit.c"
#include "../vendor/lua/liolib.c"
#include "../vendor/lua/llex.c"
#include "../vendor/lua/lmathlib.c"
#include "../vendor/lua/lmem.c"
#include "../vendor/lua/loadlib.c"
#include "../vendor/lua/lobject.c"
#include "../vendor/lua/lopcodes.c"
#include "../vendor/lua/loslib.c"
#include "../vendor/lua/lparser.c"
#include "../vendor/lua/lstate.c"
#include "../vendor/lua/lstring.c"
#include "../vendor/lua/lstrlib.c"
#include "../vendor/lua/ltable.c"
#include "../vendor/lua/ltablib.c"
#include "../vendor/lua/ltm.c"
#include "../vendor/lua/lundump.c"
#include "../vendor/lua/lutf8lib.c"
#include "../vendor/lua/lvm.c"
#include "../vendor/lua/lzio.c"
