import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../duel_field_game.dart';
import '../../util/duel_field_layout.dart';
import 'player_status_layout.dart';

/// 玩家状态卡（LP 芯片，viewport 屏幕空间）：头像 + 名字 + LP，竖排。
///
/// 两张竖排芯片紧贴场地左侧：对方在上、我方在下。横/纵位置经
/// [DuelFieldGame.worldToWidget] 对齐棋盘左沿与各自半场中心，
/// 随相机缩放/平移同步。手牌栏隐藏（等待室/猜拳等）时一并隐藏。
class PlayerStatusCardComponent extends PositionComponent
    with HasGameReference<DuelFieldGame> {
  PlayerStatusCardComponent({required this.isSelf})
    : super(anchor: Anchor.center, size: Vector2(_baseWidth, _baseHeight));

  final bool isSelf;

  static const _baseWidth = 150.0;
  static const _baseHeight = 104.0;
  /// 芯片右缘与棋盘左沿的间隙。
  static const _boardGap = 8.0;

  static const _accent = Color(0xFF00F0FF);
  static const _oppBorder = Color(0xFFFF4B82);
  static const _oppLp = Color(0xFFFF9FBB);

  static final _fillPaint = Paint()..color = const Color(0xE6080E18);

  static final _namePaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      fontFamily: 'Orbitron',
    ),
  );

  static final _avatarTextPaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 12,
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

  /// 棋盘左沿的世界 x（最左卡槽列左缘）。
  static double get _boardLeftWorldX =>
      -(DuelFieldLayout.lastColX + DuelFieldLayout.slotWidth / 2); // -286

  /// 贴到棋盘左沿（屏幕坐标），对方上我方下。
  void _syncLayout() {
    scale = Vector2.all(1.0);
    final halfW = _baseWidth / 2;
    final boardLeftScreen = game.worldToWidget(Vector2(_boardLeftWorldX, 0)).dx;
    final x = boardLeftScreen - _boardGap - halfW;
    final y = game
        .worldToWidget(
          Vector2(
            0,
            isSelf
                ? PlayerStatusLayout.selfCenterY
                : PlayerStatusLayout.oppCenterY,
          ),
        )
        .dy;
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

    final cx = size.x / 2;
    const avatarRadius = 16.0;
    final avatarCenter = Offset(cx, 24.0);
    final avatarRect = Rect.fromCircle(
      center: avatarCenter,
      radius: avatarRadius,
    );

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

    // 名字（完整显示，竖排居中）。
    _namePaint.render(
      canvas,
      name,
      Vector2(cx, 56.0),
      anchor: Anchor.center,
    );

    // LP 大数字。
    TextPaint(
      style: TextStyle(
        color: lpColor,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        fontFamily: 'Orbitron',
      ),
    ).render(
      canvas,
      '$lp',
      Vector2(cx, 84.0),
      anchor: Anchor.center,
    );
  }
}
