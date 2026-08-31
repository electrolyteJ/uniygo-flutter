import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../duel_field_world.dart';
import '../../models/flame_field_snapshot.dart';
import 'player_status_layout.dart';

/// 玩家状态卡（Flame 版）：紧贴场地左侧竖排两张，对方卡在上
/// （靠近对方半场）、我方卡在下。
///
/// 紧凑竖版布局（几何全部来自 [PlayerStatusLayout]）：
/// 头像圆（渐变+首字母）→ 名字 → LP 大数字 → H/D/EX/GY/B 五行计数。
/// 数据每帧直读 [DuelFlameGame.snapshot]，不做任何补间动画。
///
/// 交互：EX/GY/B 三行可点（命中行矩形），经 game.onZoneInspect
/// 打开对应区域浏览器；其余区域不响应点击。
class PlayerStatusCardComponent extends PositionComponent
    with TapCallbacks, HasWorldReference<DuelFieldWorld> {
  PlayerStatusCardComponent({required this.isSelf})
    : super(
        anchor: Anchor.center,
        size: Vector2(
          PlayerStatusLayout.cardWidth,
          PlayerStatusLayout.cardHeight,
        ),
      );

  /// 是否为我方卡（决定纵向位置、配色与数据源）。
  final bool isSelf;

  static const _accent = Color(0xFF00F0FF);
  static const _oppBorder = Color(0xFFFF4B82);
  static const _oppLp = Color(0xFFFF9FBB);
  static const _subtitle = Color(0xFF8B9BB4);

  static final _fillPaint = Paint()..color = const Color(0xE6080E18);

  static final _namePaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 9,
      fontWeight: FontWeight.w800,
      fontFamily: 'Orbitron',
    ),
  );
  static final _rowLabelPaint = TextPaint(
    style: const TextStyle(
      color: _subtitle,
      fontSize: 9,
      fontFamily: 'Orbitron',
    ),
  );
  static final _rowValuePaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 9,
      fontWeight: FontWeight.w800,
      fontFamily: 'Orbitron',
    ),
  );

  double _lastAnchorX = double.nan;
  double _lastAnchorY = double.nan;

  void _syncPosition() {
    final anchor = world.project3D(
      PlayerStatusLayout.centerX,
      isSelf
          ? PlayerStatusLayout.selfCenterY
          : PlayerStatusLayout.oppCenterY,
    );
    if (anchor.x == _lastAnchorX && anchor.y == _lastAnchorY) return;
    _lastAnchorX = anchor.x;
    _lastAnchorY = anchor.y;
    position = anchor;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _syncPosition();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _syncPosition();
  }

  @override
  void render(Canvas canvas) {
    // 紧凑 HUD 模式（小屏）：竖版状态卡让位给 widget 层的状态芯片
    // （两张 224 高的竖卡在小屏上互相重叠且随 zoom 缩到不可读）。
    if (world.game.compactHud) return;
    final snapshot = world.game.snapshot;
    final borderColor = isSelf
        ? _accent.withValues(alpha: 0.3)
        : _oppBorder.withValues(alpha: 0.34);
    final lpColor = isSelf ? _accent : _oppLp;

    // 卡片底板。
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size.toSize(),
      const Radius.circular(12),
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
    final name = isSelf ? snapshot.selfName : snapshot.oppName;

    // 头像圆：渐变底 + 描边 + 首字母。
    final avatarCenter = Offset(cx, PlayerStatusLayout.avatarCenterY);
    final avatarRect = Rect.fromCircle(
      center: avatarCenter,
      radius: PlayerStatusLayout.avatarRadius,
    );
    canvas.drawCircle(
      avatarCenter,
      PlayerStatusLayout.avatarRadius,
      Paint()
        ..shader = ui.Gradient.linear(
          avatarRect.topLeft,
          avatarRect.bottomRight,
          isSelf
              ? const [_accent, Color(0xFF0077FF)]
              : const [Color(0xFFFF6698), Color(0xFF9F2257)],
        ),
    );
    canvas.drawCircle(
      avatarCenter,
      PlayerStatusLayout.avatarRadius,
      Paint()
        ..color = isSelf ? _accent : const Color(0xFFFF6698)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _namePaint.render(
      canvas,
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      Vector2(cx, PlayerStatusLayout.avatarCenterY),
      anchor: Anchor.center,
    );

    // 名字（过长截断：卡内容宽 40，9pt 约容 4 个 CJK 字符）。
    final displayName = name.length > 5 ? '${name.substring(0, 4)}…' : name;
    _namePaint.render(
      canvas,
      displayName,
      Vector2(cx, PlayerStatusLayout.nameCenterY),
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
      '${isSelf ? snapshot.selfLp : snapshot.opponentLp}',
      Vector2(cx, PlayerStatusLayout.lpCenterY),
      anchor: Anchor.center,
    );

    // 计数行：H/D/EX/GY/B。
    final counts = _counts(snapshot);
    for (var i = 0; i < PlayerStatusLayout.rowLabels.length; i++) {
      final y = PlayerStatusLayout.rowCenterY(i);
      _rowLabelPaint.render(
        canvas,
        '${PlayerStatusLayout.rowLabels[i]}:',
        Vector2(PlayerStatusLayout.padding, y),
        anchor: Anchor.centerLeft,
      );
      _rowValuePaint.render(
        canvas,
        '${counts[i]}',
        Vector2(size.x - PlayerStatusLayout.padding, y),
        anchor: Anchor.centerRight,
      );
    }
  }

  /// 当前快照的五行计数（H 手牌 / D 卡组 / EX 额外 / GY 墓地 / B 除外）。
  List<int> _counts(FlameFieldSnapshot snapshot) {
    if (isSelf) {
      return [
        snapshot.selfHand.codes.length,
        snapshot.selfDeck,
        snapshot.selfExtra,
        snapshot.selfGrave,
        snapshot.selfRemoved,
      ];
    }
    return [
      snapshot.oppHand.codes.length,
      snapshot.oppDeck,
      snapshot.oppExtra,
      snapshot.oppGrave,
      snapshot.oppRemoved,
    ];
  }

  /// 可点行（EX/GY/B）对应的区域浏览器 key。
  String? _zoneKeyForRow(int rowIndex) {
    final label = PlayerStatusLayout.rowLabels[rowIndex];
    final prefix = isSelf ? 'self' : 'opp';
    return switch (label) {
      'EX' => '${prefix}_extra',
      'GY' => '${prefix}_grave',
      'B' => '${prefix}_removed',
      _ => null,
    };
  }

  // onTapUp 而非 onTapDown：与双指捏合缩放共存（见 slot.dart 注释）。
  @override
  void onTapUp(TapUpEvent event) {
    // 紧凑模式下由 widget 层状态芯片承担交互。
    if (world.game.compactHud) return;
    final y = event.localPosition.y;
    for (var i = 0; i < PlayerStatusLayout.rowLabels.length; i++) {
      final key = _zoneKeyForRow(i);
      if (key == null) continue;
      if ((y - PlayerStatusLayout.rowCenterY(i)).abs() <=
          PlayerStatusLayout.rowHeight / 2) {
        world.game.onZoneInspect?.call(key);
        return;
      }
    }
  }
}
