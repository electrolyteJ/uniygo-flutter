import 'dart:math';
import 'dart:ui' as ui;
import 'package:duelink/duelink.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:biz/duel/models/field_card.dart';
import 'package:duel_room1/field/models/flame_field_snapshot.dart';
import 'package:duel_room1/field/models/zone_slot_spec.dart';
import 'package:duel_room1/field/duel_field_world.dart';
import 'deck_shuffle_effect.dart';

/// 场地区域组件：持有全部卡槽（[CardSlotComponent]），负责按
/// [FlameFieldSnapshot] 构建槽位布局、重建，以及鼠标移动时的视差重投影。
///
/// 卡槽作为本组件的子节点，位置使用世界坐标（由 [DuelFieldWorld.project3D]
/// 投影），本组件本身无变换，故子节点世界坐标 = 棋盘世界坐标。
class ZonesComponent extends Component with HasWorldReference<DuelFieldWorld> {
  final Function(FieldCard? card, int? code)? onCardSelect;
  final void Function(String zoneKey)? onZoneInspect;

  /// 点击可放置槽位（MSG_SELECT_PLACE）的回调（槽位 key 为
  /// `controller_zone_sequence`）。
  final void Function(String slotKey)? onPlaceSlotTap;

  /// 槽位静态规格（布局期确定，整场对局复用）；与 [_slots] 一一对应。
  /// 朝向（self/opp）在首次构建时从快照烘焙，若 [FlameFieldSnapshot.myController]
  /// 变化（首推真实状态晚于布局构建时）需整体重建，见 [rebuild]。
  late List<ZoneSlotSpec> _specs;
  final List<CardSlotComponent> _slots = [];

  /// 构建 [_specs] 时使用的 myController（朝向一致性校验）。
  int? _specsController;
  Vector2? _lastParallaxMouse;
  int _lastShuffleTick = 0;

  /// 当前状态快照（widget 层经游戏推入）。
  FlameFieldSnapshot get _snapshot => world.game.snapshot;

  ZonesComponent({this.onCardSelect, this.onZoneInspect, this.onPlaceSlotTap});

  @override
  void update(double dt) {
    super.update(dt);
    _syncParallax();
    _spawnShuffleEffect();
  }

  /// 监听卡组洗切信号，在对应卡组槽位上播放洗牌动效。
  void _spawnShuffleEffect() {
    final tick = _snapshot.deckShuffleTick;
    if (tick == 0 || tick == _lastShuffleTick) return;
    _lastShuffleTick = tick;
    final isSelf = _snapshot.deckShufflePlayer == _snapshot.myController;
    final x = isSelf ? DuelFieldLayout.colX[6] : DuelFieldLayout.colX[0];
    final y = isSelf ? DuelFieldLayout.stY : -DuelFieldLayout.stY;
    world.add(DeckShuffleEffect(position: world.project3D(x, y)));
  }

  /// 鼠标移动时重新投影卡槽位置（BoardMesh / PhaseLamp 每帧自行投影，无需同步）。
  void _syncParallax() {
    final mouse = world.game.mousePos;
    final last = _lastParallaxMouse;
    if (last != null && last.x == mouse.x && last.y == mouse.y) return;
    _lastParallaxMouse = mouse.clone();
    for (final slot in _slots) {
      slot.position = world.project3D(slot.boardX, slot.boardY);
    }
  }

  /// 布局期一次性创建全部槽位；之后快照变化只原地更新内容，
  /// 不再销毁重建组件（消除对局中"组件拆装帧"导致的棋盘闪动，
  /// 同时保留卡图缓存与 hover 动画状态）。
  ///
  /// 例外：首次构建可能早于第一份真实快照（此时快照是 empty()
  /// 占位，myController=0）；当真实 myController 到达且与烘焙朝向
  /// 不一致时，销毁重建全部槽位修正朝向（一场对局至多发生一次）。
  void rebuild() {
    final snapshot = _snapshot;
    if (_slots.isEmpty || _specsController != snapshot.myController) {
      _buildAllSlots(snapshot);
      return;
    }
    for (var i = 0; i < _slots.length; i++) {
      _syncSlot(_specs[i], _slots[i], snapshot);
    }
  }

  void _buildAllSlots(FlameFieldSnapshot snapshot) {
    // 朝向变化触发的重建：先移除旧槽位。
    for (final slot in _slots) {
      slot.removeFromParent();
    }
    _slots.clear();
    _specs = buildZoneSlotSpecs(snapshot);
    _specsController = snapshot.myController;
    for (final spec in _specs) {
      final slot = CardSlotComponent(
        label: spec.label,
        boardX: spec.boardX,
        boardY: spec.boardY,
        isMonster: spec.isMonster,
        isEMZ: spec.isEMZ,
      )..position = world.project3D(spec.boardX, spec.boardY);
      _slots.add(slot);
      add(slot);
      _syncSlot(spec, slot, snapshot);
    }
  }

  /// 单槽原地同步：从快照解析卡与高亮/放置态，更新组件字段。
  void _syncSlot(
    ZoneSlotSpec spec,
    CardSlotComponent slot,
    FlameFieldSnapshot snapshot,
  ) {
    final interaction = resolveSlotInteraction(snapshot, spec.slotKeys);
    final VoidCallback onTap = switch (spec.tapBehavior) {
      ZoneSlotTapBehavior.inspect => () => onZoneInspect?.call(
        spec.inspectZoneKey!,
      ),
      ZoneSlotTapBehavior.none => () {},
      // 放置目标优先；默认点卡分发读取 slot.card 当前值，
      // 避免闭包捕获过期卡片。
      ZoneSlotTapBehavior.select =>
        interaction.placeTargetKey != null
            ? () => onPlaceSlotTap?.call(interaction.placeTargetKey!)
            : () => onCardSelect?.call(slot.card, slot.card?.code),
    };
    slot.updateContent(
      card: spec.resolveCard(snapshot),
      highlight: interaction.highlight,
      onTap: onTap,
    );
  }
}

class CardSlotComponent extends PositionComponent
    with TapCallbacks, HoverCallbacks, HasWorldReference<DuelFieldWorld> {
  /// hover 动画曲线，与 HTML transition: 0.3s cubic-bezier(0.34, 1.56, 0.64, 1) 一致。
  static const _hoverCurve = Cubic(0.34, 1.56, 0.64, 1);
  static const _hoverScale = 1.12;
  static const _hoverLift = 28.0;

  /// YGO position 位掩码。
  /// 0x1=表侧攻击, 0x2=里侧攻击, 0x4=表侧守备, 0x8=里侧守备。
  static const int _posFacedownMask = 0x0A; // 0x2 | 0x8
  static const int _posDefenseMask = 0x0C; // 0x4 | 0x8

  // TextPaint 内部按文本缓存 TextPainter，避免每帧重新 layout。
  static final _labelPaint = TextPaint(
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.35),
      fontSize: 9,
      fontWeight: FontWeight.w800,
      fontFamily: 'Orbitron',
    ),
  );
  static final _atkBadgePaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFF6193),
      fontSize: 8,
      fontWeight: FontWeight.w900,
      fontFamily: 'Orbitron',
    ),
  );
  static final _defBadgePaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFF00F0FF),
      fontSize: 8,
      fontWeight: FontWeight.w900,
      fontFamily: 'Orbitron',
    ),
  );
  static final _codePaint = TextPaint(
    style: TextStyle(
      color: Colors.white54,
      fontSize: 8,
      fontFamily: 'Orbitron',
    ),
  );

  // card/highlight/onTap 为非 final：组件布局期一次性创建，
  // 快照变化经 [updateContent] 原地更新，不销毁重建。
  FieldCard? card;
  final String label;
  final double boardX;
  final double boardY;
  final bool isMonster;
  final bool isEMZ;
  CardSlotHighlight highlight;
  VoidCallback? onTap;

  bool _hovered = false;
  double _liftZ = 0; // Z轴提升高度 (模拟 translateZ)
  Effect? _scaleFx;
  Effect? _liftFx;

  /// 已加载的卡图（表侧卡牌才加载）。
  ui.Image? _cardImage;
  bool _imageRequested = false;
  bool _disposed = false;

  CardSlotComponent({
    this.card,
    required this.label,
    required this.boardX,
    required this.boardY,
    this.isMonster = false,
    this.isEMZ = false,
    this.highlight = CardSlotHighlight.none,
    this.onTap,
  }) : super(
         size: Vector2(DuelFieldLayout.slotWidth, DuelFieldLayout.slotHeight),
         anchor: Anchor.center,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
  }

  @override
  void onMount() {
    super.onMount();
    _requestCardImage();
  }

  @override
  void onRemove() {
    _disposed = true;
    super.onRemove();
  }

  /// 原地更新槽位内容（diff 更新：快照变化时不再销毁重建组件）。
  ///
  /// 卡图缓存按 code 变化重置：同 code 的位置/攻守变化复用已加载图；
  /// 里侧→表侧（同 code，如翻转/月之书类）时 [_requestCardImage] 补发加载。
  void updateContent({
    required FieldCard? card,
    required CardSlotHighlight highlight,
    required VoidCallback? onTap,
  }) {
    final prevCode = this.card?.code;
    if (card == null || card.code != prevCode) {
      _cardImage = null;
      _imageRequested = false;
    }
    this.card = card;
    this.highlight = highlight;
    this.onTap = onTap;
    _requestCardImage();
  }

  /// 表侧卡牌请求加载卡图：先查缓存，命中则同步赋值，否则异步加载。
  void _requestCardImage() {
    if (card == null || _imageRequested) return;
    final isFacedown = (card!.position & _posFacedownMask) != 0;
    if (isFacedown) return; // 里侧卡牌不需要卡图
    _imageRequested = true;

    final cached = world.getCachedCardImage(card!.code);
    if (cached != null) {
      _cardImage = cached;
      return;
    }
    world.loadCardImage(card!.code).then((image) {
      if (image != null && !_disposed) _cardImage = image;
    });
  }

  /// hover 缩放/提升共用 [_hoverCurve]：缩放走 Flame 内置的
  /// [ScaleEffect]（围绕 anchor 中心、命中测试自动适配），lift 需经过
  /// [DuelFieldWorld.projectLiftY] 投影，用 [FunctionEffect] 从当前值起播，
  /// 中途反向不会跳变。
  void _animateHover(bool hovering) {
    _scaleFx?.removeFromParent();
    _liftFx?.removeFromParent();
    final startLift = _liftZ;
    final endLift = hovering ? _hoverLift : 0.0;
    _scaleFx = ScaleEffect.to(
      Vector2.all(hovering ? _hoverScale : 1.0),
      CurvedEffectController(0.3, _hoverCurve),
    );
    _liftFx = FunctionEffect<CardSlotComponent>(
      (target, progress) =>
          target._liftZ = startLift + (endLift - startLift) * progress,
      CurvedEffectController(0.3, _hoverCurve),
    );
    addAll([_scaleFx!, _liftFx!]);
  }

  @override
  void render(Canvas canvas) {
    const cardW = DuelFieldLayout.slotWidth;
    const cardH = DuelFieldLayout.slotHeight;

    // 1. 组件 position 已由 world 投影设置，hover 缩放由 Flame transform
    // 围绕 anchor(中心) 应用；此处仅叠加 Z 轴提升位移（世界坐标 y 方向），
    // 除以 scale.y 抵消变换缩放，保持世界坐标下的提升量。
    // ⚠️ 临时关闭 Z 轴提升（3D 效果），便于预览平面布局。恢复时改回：
    // final liftDy = world.projectLiftY(_liftZ) / scale.y;
    final liftDy = 0.0;

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2 + liftDy);

    final Color accentColor = isEMZ
        ? const Color(0xFFFFD700)
        : const Color(0xFF00F0FF);

    // 2. 绘制 3D 投影发光底座
    if (_hovered) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: cardW + 16,
            height: cardH + 16,
          ),
          const Radius.circular(10),
        ),
        Paint()
          ..color = accentColor.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
    }

    // 3. 槽位边框与背景 (100% 匹配 HTML .slot-3d)
    final slotRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH),
      const Radius.circular(6),
    );

    canvas.drawRRect(
      slotRRect,
      Paint()..color = accentColor.withValues(alpha: _hovered ? 0.18 : 0.04),
    );
    canvas.drawRRect(
      slotRRect,
      Paint()
        ..color = _hovered ? accentColor : accentColor.withValues(alpha: 0.35)
        ..strokeWidth = _hovered ? 2.0 : 1.5
        ..style = PaintingStyle.stroke,
    );

    if (card == null) {
      // 空位标签
      _labelPaint.render(canvas, label, Vector2.zero(), anchor: Anchor.center);
    } else {
      _renderCardBody(canvas, cardW, cardH);
    }

    // 4. 选择/放置高亮：在槽位本体上绘制发光、填充与描边，
    // 与页面手牌栏的高亮视觉语言一致（青=可选，金=已勾选）。
    if (highlight != CardSlotHighlight.none) {
      _renderHighlight(canvas, slotRRect);
    }

    canvas.restore();
  }

  void _renderHighlight(Canvas canvas, RRect slotRRect) {
    final isChecked = highlight == CardSlotHighlight.checked;
    final color = isChecked ? const Color(0xFFFFD700) : const Color(0xFF00F0FF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        slotRRect.outerRect.inflate(8),
        const Radius.circular(12),
      ),
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRRect(
      slotRRect.inflate(3),
      Paint()..color = color.withValues(alpha: isChecked ? 0.22 : 0.12),
    );
    canvas.drawRRect(
      slotRRect.inflate(3),
      Paint()
        ..color = color
        ..strokeWidth = isChecked ? 2.5 : 2.0
        ..style = PaintingStyle.stroke,
    );
  }

  void _renderCardBody(Canvas canvas, double w, double h) {
    final pos = card!.position;
    final isFacedown = (pos & _posFacedownMask) != 0;
    final isDefense = (pos & _posDefenseMask) != 0;

    // 守备表示：仅怪兽卡(zone==4)横放；魔陷卡(zone==8)始终竖放。
    // 魔陷无论盖牌(set)还是发动，卡片都保持竖方向。
    final isMonsterCard = card!.zone == 4;
    final needsRotate = isDefense && isMonsterCard;

    canvas.save();
    if (needsRotate) {
      canvas.rotate(pi / 2);
      canvas.scale(0.74, 0.74);
    }

    if (isFacedown) {
      _renderCardBack(canvas, w, h);
    } else {
      _renderCardFace(canvas, w, h);
    }

    canvas.restore();

    // ATK/DEF 徽章：不受旋转影响，始终竖直显示在槽位右上角
    // 位置徽标：攻/守/里侧指示
    if (!isFacedown && isMonster) {
      _renderBadge(canvas, w, h, isDefense);
    }
  }

  /// 绘制卡背（里侧卡牌）。
  void _renderCardBack(Canvas canvas, double w, double h) {
    if (card?.zone == CARD_ZONE_DECK) {
      _renderDeckBack(canvas, w, h);
      return;
    }
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: w - 2,
      height: h - 2,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));

    // 深蓝渐变背景
    final gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF31475E), Color(0xFF0A1020)],
    );
    canvas.drawRRect(rrect, Paint()..shader = gradient.createShader(rect));

    // 中心圆环（青色边框）
    canvas.drawCircle(
      Offset.zero,
      9,
      Paint()
        ..color = const Color(0x5900F0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _renderDeckBack(Canvas canvas, double w, double h) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: w - 2,
      height: h - 2,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));

    final baseGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF071018), Color(0xFF15314E), Color(0xFF050910)],
      stops: [0.0, 0.52, 1.0],
    );
    canvas.drawRRect(rrect, Paint()..shader = baseGradient.createShader(rect));

    canvas.save();
    canvas.clipRRect(rrect);

    final stripePaint = Paint()
      ..color = const Color(0x2800F0FF)
      ..strokeWidth = 2.0;
    for (
      double x = rect.left - rect.height;
      x < rect.right + rect.height;
      x += 10
    ) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        stripePaint,
      );
    }

    final center = rect.center;
    for (final radius in [12.0, 20.0, 29.0]) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0x6600F0FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius == 29.0 ? 1.2 : 1.0,
      );
    }

    final diamond = Path()
      ..moveTo(center.dx, center.dy - 15)
      ..lineTo(center.dx + 15, center.dy)
      ..lineTo(center.dx, center.dy + 15)
      ..lineTo(center.dx - 15, center.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = const Color(0x2200F0FF));
    canvas.drawPath(
      diamond,
      Paint()
        ..color = const Color(0xAA9AEFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xAA9AEFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  /// 绘制卡面（表侧卡牌）— 加载网络卡图，失败时显示占位。
  void _renderCardFace(Canvas canvas, double w, double h) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: w - 2,
      height: h - 2,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));

    if (_cardImage != null) {
      // 绘制卡图（cover 方式裁剪到圆角矩形）
      final srcRect = Rect.fromLTWH(
        0,
        0,
        _cardImage!.width.toDouble(),
        _cardImage!.height.toDouble(),
      );
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawImageRect(_cardImage!, srcRect, rect, Paint());
      canvas.restore();

      // 白色边框
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    } else {
      // 占位：棕色背景 + code 文本
      canvas.drawRRect(rrect, Paint()..color = Colors.brown.shade300);
      _codePaint.render(
        canvas,
        '${card!.code}',
        Vector2.zero(),
        anchor: Anchor.center,
      );
    }
  }

  /// 绘制 ATK/DEF 徽章 — 右上角，粉色 ATK / 青色 DEF。
  void _renderBadge(Canvas canvas, double w, double h, bool isDefense) {
    final value = isDefense ? card!.defense : card!.attack;
    final label = isDefense ? 'DEF' : 'ATK';
    final color = isDefense ? const Color(0xFF00F0FF) : const Color(0xFFFF6193);
    final text = value == null ? label : '$label $value';
    final paint = isDefense ? _defBadgePaint : _atkBadgePaint;

    final metrics = paint.getLineMetrics(text);
    final badgeW = metrics.width + 8; // 4px 左右内边距
    const badgeH = 13.0;

    // 位置：槽位右上角，right: 3, top: 3
    final badgeX = w / 2 - 3 - badgeW;
    final badgeY = -h / 2 + 3;

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeX, badgeY, badgeW, badgeH),
      const Radius.circular(4),
    );

    // 黑色半透明背景
    canvas.drawRRect(
      badgeRect,
      Paint()..color = Colors.black.withValues(alpha: 0.82),
    );
    // 彩色边框
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = color.withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 文本居中
    paint.render(
      canvas,
      text,
      Vector2(badgeX + badgeW / 2, badgeY + badgeH / 2),
      anchor: Anchor.center,
    );
  }

  @override
  void onHoverEnter() {
    _hovered = true;
    _animateHover(true);
  }

  @override
  void onHoverExit() {
    _hovered = false;
    _animateHover(false);
  }

  @override
  void onTapDown(TapDownEvent event) => onTap?.call();
}
