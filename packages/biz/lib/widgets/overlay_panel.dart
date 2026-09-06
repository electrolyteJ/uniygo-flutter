import 'dart:ui';

import 'package:flutter/material.dart';

/// 房间流程浮层面板的共用容器：半透明深色底 + 青色描边 + 圆角 +
/// 背景模糊，透出背后的决斗场地。
///
/// 等待室弹窗（WaitingRoomPage）与猜拳/选先攻面板
/// （HandSelectPanel/TurnSelectPanel）共用，视觉对齐 godot RoomOverlay
/// 的面板样式（bg Color(0.02,0.04,0.1,0.95) + 青色描边 + 圆角 8）。
class OverlayPanel extends StatelessWidget {
  final Widget child;

  const OverlayPanel({super.key, required this.child});

  /// 缓存的模糊滤镜实例：`ui.ImageFilter` 未重写 `==`，若每次 build 都新建
  /// `ImageFilter.blur(...)`，`BackdropFilter` 会误判「滤镜已变」并在面板每次
  /// 重建时重放一次高斯模糊，导致背后的内容（选卡弹窗等）整屏闪一下。
  /// 缓存同一实例后，`BackdropFilter` 只在滤镜真正变化时才重放。
  static final ImageFilter _blur = ImageFilter.blur(sigmaX: 10, sigmaY: 10);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: _blur,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF2080E18),
            border: Border.all(color: const Color(0x4D00F0FF)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 24,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
