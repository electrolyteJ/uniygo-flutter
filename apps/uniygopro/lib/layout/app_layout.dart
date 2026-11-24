import 'package:flutter/widgets.dart';

/// 应用级布局档位。
///
/// 判定优先级从上到下，边界值（恰好等于阈值）归入尺寸更大的档位：
/// - [compact]：可用宽 `< 1024` 或可用高 `< 600`；
/// - [regular]：不属于 [compact]，且宽 `< 1600` 或高 `< 900`；
/// - [wide]：宽 `>= 1600` 且高 `>= 900`。
enum AppLayoutTier { compact, regular, wide }

/// 应用级响应式布局规格。
///
/// 纯派生自真实视口与安全区，不持有业务状态。页面通过 [AppLayout.of] 读取，
/// 用于决定导航形态（底部 Tab / 左侧 Rail）、栏数与信息密度。
@immutable
class AppLayoutSpec {
  const AppLayoutSpec({
    required this.tier,
    required this.viewport,
    required this.safePadding,
    required this.isTouch,
    required this.pagePadding,
    required this.gutter,
    required this.railWidth,
    required this.contentColumns,
    required this.maxContentWidth,
    required this.bottomTabHeight,
  });

  /// 当前档位。
  final AppLayoutTier tier;

  /// 真实逻辑视口尺寸（来自 `MediaQuery.size`，未被改写）。
  final Size viewport;

  /// 安全区（刘海 / 圆角 / Home 指示条）。
  final EdgeInsets safePadding;

  /// 是否以触控为主要输入。
  final bool isTouch;

  /// 页面外边距。
  final double pagePadding;

  /// 板块间距。
  final double gutter;

  /// 桌面左侧导航栏宽度；[AppLayoutTier.compact] 下不使用 Rail。
  final double railWidth;

  /// 大厅内容列数。
  final int contentColumns;

  /// 内容区最大宽度，超出后居中，避免超宽屏拉伸。
  final double maxContentWidth;

  /// 移动端底部 Tab 高度；[AppLayoutTier.compact] 下生效。
  final double bottomTabHeight;

  /// 最小交互命中尺寸（视觉元素可更小，命中区不得小于此值）。
  double get minimumTapExtent => 44;

  /// 是否使用桌面左侧 Rail 导航。
  bool get usesRail => tier != AppLayoutTier.compact;

  /// 零尺寸兜底：按 1280×800 的 regular 档处理，保证不产生负约束。
  static const AppLayoutSpec fallback = AppLayoutSpec(
    tier: AppLayoutTier.regular,
    viewport: Size(1280, 800),
    safePadding: EdgeInsets.zero,
    isTouch: false,
    pagePadding: 20,
    gutter: 16,
    railWidth: 88,
    contentColumns: 2,
    maxContentWidth: 1600,
    bottomTabHeight: 56,
  );

  /// 由真实视口与安全区推导规格。
  ///
  /// [size] 与 [padding] 非法（零或负）时返回 [fallback]。
  /// [isTouch] 默认按短边小于 900 判定为触控设备。
  static AppLayoutSpec resolve(
    Size size,
    EdgeInsets padding, {
    bool? isTouch,
  }) {
    if (size.width <= 0 || size.height <= 0) return fallback;

    final tier = resolveTier(size, padding);
    final touch = isTouch ?? size.shortestSide < 900;

    return switch (tier) {
      AppLayoutTier.compact => AppLayoutSpec(
        tier: tier,
        viewport: size,
        safePadding: padding,
        isTouch: touch,
        pagePadding: 12,
        gutter: 12,
        railWidth: 0,
        contentColumns: 1,
        maxContentWidth: size.width,
        bottomTabHeight: 56,
      ),
      AppLayoutTier.regular => AppLayoutSpec(
        tier: tier,
        viewport: size,
        safePadding: padding,
        isTouch: touch,
        pagePadding: 20,
        gutter: 16,
        railWidth: 88,
        contentColumns: 2,
        maxContentWidth: 1600,
        bottomTabHeight: 56,
      ),
      AppLayoutTier.wide => AppLayoutSpec(
        tier: tier,
        viewport: size,
        safePadding: padding,
        isTouch: touch,
        pagePadding: 28,
        gutter: 22,
        railWidth: 104,
        contentColumns: 3,
        maxContentWidth: 1600,
        bottomTabHeight: 56,
      ),
    };
  }

  /// 仅推导档位（供测试与纯逻辑复用）。
  static AppLayoutTier resolveTier(Size size, EdgeInsets padding) {
    final w = size.width - padding.horizontal;
    final h = size.height - padding.vertical;
    if (w < 1024 || h < 600) return AppLayoutTier.compact;
    if (w < 1600 || h < 900) return AppLayoutTier.regular;
    return AppLayoutTier.wide;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLayoutSpec &&
          tier == other.tier &&
          viewport == other.viewport &&
          safePadding == other.safePadding &&
          isTouch == other.isTouch &&
          pagePadding == other.pagePadding &&
          gutter == other.gutter &&
          railWidth == other.railWidth &&
          contentColumns == other.contentColumns &&
          maxContentWidth == other.maxContentWidth &&
          bottomTabHeight == other.bottomTabHeight;

  @override
  int get hashCode => Object.hash(
    tier,
    viewport,
    safePadding,
    isTouch,
    pagePadding,
    gutter,
    railWidth,
    contentColumns,
    maxContentWidth,
    bottomTabHeight,
  );
}

/// 应用级布局规格注入点。
///
/// 在 [MaterialApp.router] 的 `builder` 中注入一次，页面通过
/// [AppLayout.of] 读取当前视口推导出的规格。
class AppLayout extends InheritedWidget {
  const AppLayout({super.key, required this.spec, required super.child});

  final AppLayoutSpec spec;

  static AppLayoutSpec of(BuildContext context) =>
      maybeOf(context) ?? AppLayoutSpec.fallback;

  static AppLayoutSpec? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLayout>()?.spec;

  @override
  bool updateShouldNotify(AppLayout oldWidget) => oldWidget.spec != spec;
}

/// 在 [AppLayout] 作用域内按真实视口构建子树的便捷组件。
///
/// 直接读取父级 `MediaQuery`（不修改），因此页面内所有断点判断都基于
/// 设备真实分辨率，而非固定设计尺寸。
class AppLayoutScope extends StatelessWidget {
  const AppLayoutScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final spec = AppLayoutSpec.resolve(mediaQuery.size, mediaQuery.padding);
    return AppLayout(spec: spec, child: child);
  }
}
