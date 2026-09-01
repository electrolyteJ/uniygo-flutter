# debug

YGO 客户端的调试预览包：脱离完整 app，独立运行各模块的可视化预览/调试入口。

## 运行

默认入口（调试 Hub，列出所有预览页）：

    flutter run

也可直接指定入口：

    flutter run -t lib/main_duel1.dart        # duel_room1 2D 场地
    flutter run -t lib/main_preview3d.dart    # duel_room3 3D 场景
    flutter run -t lib/main_deck3.dart        # deck_editor3 卡组中心

3D 场景预览（duel_room3）依赖 Flutter GPU，桌面端需显式开启：

    flutter run -t lib/main_preview3d.dart --enable-flutter-gpu

Android/iOS 已在工程配置中默认开启 Flutter GPU（EnableFlutterGPU /
FLTEnableFlutterGPU）并锁定横屏，无需额外参数。
