Pod::Spec.new do |s|
  s.name             = 'ocgcore'
  s.version          = '1.0.0'
  s.summary          = 'YGOPRO ocgcore duel engine'
  s.homepage         = 'https://github.com/electrolyteJ/ygopro-core'
  s.license          = { :type => 'MIT' }
  s.author           = { 'electrolyteJ' => '' }
  s.platform         = :ios, '12.0'
  s.source           = { :path => '.' }

  # 源码构建:ocgcore + Lua 5.3(卡牌脚本解释器依赖)。
  # ocgcore 以 C++ 符号名引用 Lua API(与上游一致),vendor/lua 以聚合
  # 编译单元(C++)并入(src/lua_amalgam.cpp),排除带 main() 的
  # lua.c / luac.c 与 onelua.c。vendor 为指向包根 vendor/ 的符号链接。
  s.source_files = 'vendor/ocgcore/*.{cpp,h}', 'src/lua_amalgam.cpp', 'src/*.h'

  s.xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/vendor/lua"'
  }
  s.static_framework = true
end
