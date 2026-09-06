import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 决斗房间运行平台类型。
enum DuelPlatform {
  android,
  ios,
  windows,
  macos,
  linux,
  web,
}

/// 跨平台 UI 适配工具：统一判断当前运行平台、输入设备倾向及响应式断点。
///
/// 用法：
/// ```dart
/// final adaptive = PlatformAdaptive.of(context);
/// if (adaptive.isDesktop) { ... }
/// ```
///
/// 设计目标：
/// - 把所有 `defaultTargetPlatform` / `kIsWeb` 判断收敛到一处，避免散落。
/// - 提供「是否支持悬停/右键/滚轮」等语义化判断，供 widget 层按平台裁剪交互。
/// - 响应式断点兼顾桌面窗口、浏览器窗口与手机横屏。
class PlatformAdaptive {
  const PlatformAdaptive._({required this.platform});

  final DuelPlatform platform;

  factory PlatformAdaptive.of(BuildContext context) {
    if (kIsWeb) return const PlatformAdaptive._(platform: DuelPlatform.web);
    return PlatformAdaptive._(platform: _platformFromTargetPlatform(defaultTargetPlatform));
  }

  static DuelPlatform _platformFromTargetPlatform(TargetPlatform p) {
    return switch (p) {
      TargetPlatform.android => DuelPlatform.android,
      TargetPlatform.iOS => DuelPlatform.ios,
      TargetPlatform.windows => DuelPlatform.windows,
      TargetPlatform.macOS => DuelPlatform.macos,
      TargetPlatform.linux => DuelPlatform.linux,
      TargetPlatform.fuchsia => DuelPlatform.linux,
    };
  }

  bool get isWeb => platform == DuelPlatform.web;

  bool get isMobile => platform == DuelPlatform.android || platform == DuelPlatform.ios;

  bool get isDesktop =>
      platform == DuelPlatform.windows ||
      platform == DuelPlatform.macos ||
      platform == DuelPlatform.linux;

  /// 是否适合展示悬停/PointerHover 反馈。
  /// Web 与桌面默认具备鼠标；移动平台以触控为主，不启用 hover 特效。
  bool get supportsHover => isDesktop || isWeb;

  /// 是否支持鼠标右键（secondary click）上下文菜单。
  bool get supportsContextMenu => isDesktop || isWeb;

  /// 是否支持滚轮缩放/滚动。
  bool get supportsScrollWheel => isDesktop || isWeb;

  /// 是否使用紧凑触控热区（桌面鼠标精度高，可适当缩小；手机必须 >= 44）。
  bool get useCompactHitTarget => isDesktop;

  /// 当前运行平台名称（日志/调试用）。
  String get name => platform.name;
}

/// 平台相关的鼠标光标包装。
///
/// 在桌面/Web 把 [child] 包进 [MouseRegion] 显示点击手型；
/// 在移动平台原样返回 [child]，避免无意义的 HitTest 开销。
class ClickableCursor extends StatelessWidget {
  final Widget child;
  final SystemMouseCursor cursor;

  const ClickableCursor({
    super.key,
    required this.child,
    this.cursor = SystemMouseCursors.click,
  });

  @override
  Widget build(BuildContext context) {
    final adaptive = PlatformAdaptive.of(context);
    if (!adaptive.supportsHover) return child;
    return MouseRegion(
      cursor: cursor,
      child: child,
    );
  }
}

/// 平台相关的悬停高亮包装。
///
/// 桌面/Web 下鼠标悬停时给 [child] 叠加半透明背景；移动端不启用。
class HoverHighlight extends StatefulWidget {
  final Widget child;
  final Color hoverColor;

  const HoverHighlight({
    super.key,
    required this.child,
    this.hoverColor = const Color(0x1AFFFFFF),
  });

  @override
  State<HoverHighlight> createState() => _HoverHighlightState();
}

class _HoverHighlightState extends State<HoverHighlight> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final adaptive = PlatformAdaptive.of(context);
    if (!adaptive.supportsHover) return widget.child;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovering ? widget.hoverColor : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}
