import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../duel_field_game.dart';
import '../hand_card/hand_bar_component.dart';

/// 玩家状态卡（LP 芯片，viewport 屏幕空间）：头像 + 名字 + LP 大数字。
///
/// 普通与紧凑模式统一挂 viewport（与 HandBarComponent/LpChangeToastComponent
/// 同层），不随场地相机缩放；尺寸按 [DuelFieldGame.hudScale] 等比适配，
/// 手牌栏隐藏（等待室/猜拳等）时一并隐藏。
///
/// 定位：我方贴底居左（己方手牌左侧），对方贴顶居右（对方手牌右侧）。
class PlayerStatusCardComponent extends PositionComponent
    with HasGameReference<DuelFieldGame> {
  PlayerStatusCardComponent({required this.isSelf})
    : super(anchor: Anchor.center, size: Vector2(_baseWidth, _baseHeight));

  final bool isSelf;

  static const _baseWidth = 120.0;
  static const _baseHeight = 34.0;
  static const _margin = 8.0;

  static const _accent = Color(0xFF00F0FF);
  static const _oppBorder = Color(0xFFFF4B82);
  static const _oppLp = Color(0xFFFF9FBB);

  static final _fillPaint = Paint()..color = const Color(0xE6080E18);

  static final _namePaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      fontFamily: 'Orbitron',
    ),
  );

  static final _avatarTextPaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      fontFamily: 'Orbitron',
    ),
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _syncLayout();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _syncLayout();
  }

  /// 按 hudScale 等比缩放并定位到对应手牌栏侧方（屏幕坐标）。
  void _syncLayout() {
    final hs = game.hudScale;
    scale = Vector2.all(hs);
    final barVisualH = HandBarComponent.barHeight * hs;
    final halfW = _baseWidth * hs / 2;
    final oppTopY = game.oppHandBar?.hudTopY ?? 0;
    final y = isSelf
        ? game.size.y -
              game.viewPadding.bottom -
              HandBarComponent.bottomPadding -
              barVisualH / 2
        : oppTopY + barVisualH / 2;
    final x = isSelf
        ? game.viewPadding.left + _margin * hs + halfW
        : game.size.x - game.viewPadding.right - _margin * hs - halfW;
    position = Vector2(x, y);
  }

  @override
  void render(Canvas canvas) {
    if (!game.handBarsVisible) return;
    final snapshot = game.snapshot;
    final name = isSelf ? snapshot.selfName : snapshot.oppName;
    final lp = isSelf ? snapshot.selfLp : snapshot.opponentLp;
    final lpColor = isSelf ? _accent : _oppLp;
    final borderColor = isSelf
        ? _accent.withValues(alpha: 0.3)
        : _oppBorder.withValues(alpha: 0.34);

    // 底板。
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size.toSize(),
      const Radius.circular(16),
    );
    canvas.drawRRect(rect, _fillPaint);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final h = size.y;
    final avatarRadius = h * 0.32;
    final avatarCenter = Offset(avatarRadius + 6, h / 2);
    final avatarRect = Rect.fromCircle(center: avatarCenter, radius: avatarRadius);

    // 头像圆：渐变底 + 描边 + 首字母。
    canvas.drawCircle(
      avatarCenter,
      avatarRadius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSelf
              ? const [_accent, Color(0xFF0077FF)]
              : const [Color(0xFFFF6698), Color(0xFF9F2257)],
        ).createShader(avatarRect),
    );
    canvas.drawCircle(
      avatarCenter,
      avatarRadius,
      Paint()
        ..color = isSelf ? _accent : const Color(0xFFFF6698)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    _avatarTextPaint.render(
      canvas,
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      Vector2(avatarCenter.dx, avatarCenter.dy),
      anchor: Anchor.center,
    );

    // 名字（过长截断）。
    final displayName = name.length > 5 ? '${name.substring(0, 4)}…' : name;
    _namePaint.render(
      canvas,
      displayName,
      Vector2(avatarCenter.dx + avatarRadius + 6, h / 2),
      anchor: Anchor.centerLeft,
    );

    // LP 大数字（右对齐）。
    TextPaint(
      style: TextStyle(
        color: lpColor,
        fontSize: 15,
        fontWeight: FontWeight.w900,
        fontFamily: 'Orbitron',
      ),
    ).render(
      canvas,
      '$lp',
      Vector2(size.x - 8, h / 2),
      anchor: Anchor.centerRight,
    );
  }
}
