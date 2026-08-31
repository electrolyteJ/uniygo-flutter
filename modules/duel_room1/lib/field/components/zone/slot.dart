import 'dart:math';
import 'dart:ui' as ui;
import 'package:duelink/duelink.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:biz/duel/models/field_card.dart';
import 'package:duel_room1/field/components/zone/zone_slot_spec.dart';
import 'package:duel_room1/field/duel_field_world.dart';
import '../deck_shuffle_effect.dart';
class CardSlotComponent extends PositionComponent
    with TapCallbacks, HoverCallbacks, HasWorldReference<DuelFieldWorld> {
  /// hover 动画曲线，与 HTML transition: 0.3s cubic-bezier(0.34, 1.56, 0.64, 1) 一致。
  static const _hoverCurve = Cubic(0.34, 1.56, 0.64, 1);
  static const _hoverScale = 1.12;
  static const _hoverLift = 28.0;

  /// YGO position 位掩码由 duelink 常量提供：
  /// POS_FACEDOWN(0xA=0x2|0x8) / POS_DEFENSE(0xC=0x4|0x8)。
  /// 0x1=表侧攻击, 0x2=里侧攻击, 0x4=表侧守备, 0x8=里侧守备。

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

  // ── 渲染缓存 ──
  // 槽位几何全部来自 DuelFieldLayout 常量：RRect / 渐变 shader 一次性构建
  // 复用，避免每帧分配（含里侧卡背 LinearGradient.createShader）。
  // 动态 alpha / 颜色留在热路径：复用实例 Paint，每帧只改 color/strokeWidth。
  static final _slotRRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset.zero,
      width: DuelFieldLayout.slotWidth,
      height: DuelFieldLayout.slotHeight,
    ),
    const Radius.circular(6),
  );
  static final _hoverGlowRRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset.zero,
      width: DuelFieldLayout.slotWidth + 16,
      height: DuelFieldLayout.slotHeight + 16,
    ),
    const Radius.circular(10),
  );
  static final _highlightGlowRRect = RRect.fromRectAndRadius(
    _slotRRect.outerRect.inflate(8),
    const Radius.circular(12),
  );
  static final _highlightRRect = _slotRRect.inflate(3);

  /// 卡体矩形（比槽位小 2px、圆角 5）：卡背 / 卡面 / 卡组背共用。
  static final _cardRect = Rect.fromCenter(
    center: Offset.zero,
    width: DuelFieldLayout.slotWidth - 2,
    height: DuelFieldLayout.slotHeight - 2,
  );
  static final _cardRRect = RRect.fromRectAndRadius(
    _cardRect,
    const Radius.circular(5),
  );

  // 里侧卡背：深蓝渐变 + 中心圆环。
  static final _cardBackPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF31475E), Color(0xFF0A1020)],
    ).createShader(_cardRect);
  static final _cardBackRingPaint = Paint()
    ..color = const Color(0x5900F0FF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  // 卡组背：底色渐变 / 斜纹 / 同心圆 / 菱形 / 边框。
  static final _deckBackPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF071018), Color(0xFF15314E), Color(0xFF050910)],
      stops: [0.0, 0.52, 1.0],
    ).createShader(_cardRect);
  static final _deckStripePaint = Paint()
    ..color = const Color(0x2800F0FF)
    ..strokeWidth = 2.0;
  static final _deckRingPaint = Paint()
    ..color = const Color(0x6600F0FF)
    ..style = PaintingStyle.stroke;
  // 菱形路径以 _cardRect 中心（原点）为锚，几何固定。
  static final _deckDiamondPath = Path()
    ..moveTo(0, -15)
    ..lineTo(15, 0)
    ..lineTo(0, 15)
    ..lineTo(-15, 0)
    ..close();
  static final _deckDiamondFillPaint = Paint()
    ..color = const Color(0x2200F0FF);
  static final _deckDiamondStrokePaint = Paint()
    ..color = const Color(0xAA9AEFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  static final _deckBorderPaint = Paint()
    ..color = const Color(0xAA9AEFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1;

  // 卡面：卡图绘制 / 白色边框 / 加载占位。
  static final _imagePaint = Paint();
  static final _faceBorderPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.7)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final _facePlaceholderPaint = Paint()
    ..color = Colors.brown.shade300;

  // ATK/DEF 徽章：背景固定；边框颜色按攻/守两种固定值各缓存一份。
  static final _badgeBgPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.82);
  static final _atkBadgeBorderPaint = Paint()
    ..color = const Color(0xFFFF6193).withValues(alpha: 0.62)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final _defBadgeBorderPaint = Paint()
    ..color = const Color(0xFF00F0FF).withValues(alpha: 0.62)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  // 可召唤/可发动提醒角标（墓地/额外/除外区域右上角小红点）：
  // 深色底圈 + 红色圆点，保证叠在卡背/卡面上也醒目。
  static final _activatableDotBorderPaint = Paint()
    ..color = const Color(0xE6080D12);
  static final _activatableDotPaint = Paint()
    ..color = const Color(0xFFFF5252);

  // 连锁序号徽章：卡片左上角压边的金色圆徽（与手牌栏 ChainOrderBadge
  // 同一视觉语言）；停留/淡出的透明度经 saveLayer 整体作用。
  static final _chainBadgeFillPaint = Paint()..color = const Color(0xD90A101A);
  static final _chainBadgeBorderPaint = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;
  static final _chainBadgeGlowPaint = Paint()
    ..color = const Color(0x59FFD700)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  static final _chainBadgeTextPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFD700),
      fontSize: 12,
      fontWeight: FontWeight.w900,
      fontFamily: 'Orbitron',
      height: 1,
    ),
  );

  // 实例级复用 Paint：颜色/线宽随 hover、accent(isEMZ)、高亮态动态设置。
  final Paint _slotFillPaint = Paint();
  final Paint _slotStrokePaint = Paint()..style = PaintingStyle.stroke;
  final Paint _hoverGlowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
  final Paint _highlightGlowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
  final Paint _highlightFillPaint = Paint();
  final Paint _highlightStrokePaint = Paint()..style = PaintingStyle.stroke;

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

  /// 该槽位所属区域当前「有可召唤/可发动卡」（墓地/额外/除外提醒角标）。
  bool activatable;

  // ── 连锁序号徽章 ──
  /// 正在展示的连锁序号（含连锁结束后的停留期）；null = 无徽章。
  int? _chainBadgeOrder;

  /// 连锁结束（快照序号变 null）的时刻，用于停留 1s + 淡出计时。
  double? _chainBadgeClearAt;

  /// 组件本地时钟（秒），驱动徽章停留/淡出（render 每帧读取）。
  double _time = 0;

  /// 连锁结束后停留时长（秒），与手牌栏 ChainOrderBadge 一致。
  static const _chainLingerSeconds = 1.0;

  /// 停留结束后的淡出时长（秒）。
  static const _chainFadeSeconds = 0.3;

  bool _hovered = false;
  double _liftZ = 0; // Z轴提升高度 (模拟 translateZ)
  Effect? _scaleFx;
  Effect? _liftFx;

  /// 已加载的卡图（表侧卡牌才加载）。持有的是加载器缓存图的克隆
  ///（CardImageLoader LRU 超上限会 dispose 被逐出的原图），换卡与
  /// onRemove 时负责 dispose。
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
    this.activatable = false,
  }) : super(
    // 命中热区比视觉槽位大（仅影响 hit test；渲染以槽位常量为中心
    // 对称绘制，不受组件 size 影响），见 DuelFieldLayout 注释。
    size: Vector2(
      DuelFieldLayout.slotHitWidth,
      DuelFieldLayout.slotHitHeight,
    ),
    anchor: Anchor.center,
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 仅徽章存活期推进时钟：清除计时以徽章首次出现的时刻为基准。
    if (_chainBadgeOrder != null) _time += dt;
  }

  @override
  void onMount() {
    super.onMount();
    _requestCardImage();
  }

  @override
  void onRemove() {
    _disposed = true;
    _cardImage?.dispose();
    _cardImage = null;
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
    required bool activatable,
    required int? chainOrder,
  }) {
    final prevCode = this.card?.code;
    if (card == null || card.code != prevCode) {
      _cardImage?.dispose();
      _cardImage = null;
      _imageRequested = false;
    }
    this.card = card;
    this.highlight = highlight;
    this.onTap = onTap;
    this.activatable = activatable;
    _syncChainBadge(chainOrder);
    _requestCardImage();
  }

  /// 连锁序号徽章状态迁移：新序号立即展示/更新；变 null（连锁结束）
  /// 时记录清除时刻，由 render 停留 1s 后淡出；停留/淡出期间来了
  /// 新序号则取消清除立即恢复。
  void _syncChainBadge(int? chainOrder) {
    if (chainOrder != null) {
      // 徽章首次出现时从零开始计时（update 只在徽章存活期推进时钟）。
      if (_chainBadgeOrder == null) _time = 0;
      _chainBadgeOrder = chainOrder;
      _chainBadgeClearAt = null;
    } else if (_chainBadgeOrder != null && _chainBadgeClearAt == null) {
      _chainBadgeClearAt = _time;
    }
  }

  /// 表侧卡牌请求加载卡图：先查缓存，命中则同步赋值，否则异步加载。
  void _requestCardImage() {
    if (card == null || _imageRequested) return;
    final isFacedown = (card!.position & POS_FACEDOWN) != 0;
    if (isFacedown) return; // 里侧卡牌不需要卡图
    _imageRequested = true;

    final code = card!.code;
    final cached = world.getCachedCardImage(code);
    if (cached != null) {
      _cardImage = cached.clone();
      return;
    }
    world.loadCardImage(code).then((image) {
      // A→B 换卡竞态：慢请求后返回时槽位可能已是另一张卡，
      // 仅当当前卡牌仍是请求时的那张才采用结果（否则错误卡图
      // 会被 updateContent 的 code 判等保留，永久停留）。
      if (_disposed || card?.code != code) return;
      if (image != null) {
        _cardImage = image.clone();
      } else {
        // 加载失败（CardImageLoader 负缓存 30s 内直接回 null）：
        // 解除占用标记，下次 updateContent 可重试，
        // 避免一次网络抖动整局显示占位图。
        _imageRequested = false;
      }
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
        _hoverGlowRRect,
        _hoverGlowPaint..color = accentColor.withValues(alpha: 0.4),
      );
    }

    // 3. 槽位边框与背景 (100% 匹配 HTML .slot-3d)
    canvas.drawRRect(
      _slotRRect,
      _slotFillPaint
        ..color = accentColor.withValues(alpha: _hovered ? 0.18 : 0.04),
    );
    canvas.drawRRect(
      _slotRRect,
      _slotStrokePaint
        ..color = _hovered ? accentColor : accentColor.withValues(alpha: 0.35)
        ..strokeWidth = _hovered ? 2.0 : 1.5,
    );

    if (card == null) {
      // 空位标签
      _labelPaint.render(canvas, label, Vector2.zero(), anchor: Anchor.center);
    } else {
      _renderCardBody(canvas);
    }

    // 4. 选择/放置高亮：在槽位本体上绘制发光、填充与描边，
    // 与页面手牌栏的高亮视觉语言一致（青=可选，金=已勾选）。
    if (highlight != CardSlotHighlight.none) {
      _renderHighlight(canvas);
    }

    // 5. 可召唤/可发动提醒角标（墓地/额外/除外区域）。
    if (activatable) {
      _renderActivatableBadge(canvas);
    }

    // 6. 连锁序号徽章：卡片左上角压边金徽（最高层级，盖在卡面/高亮之上）。
    _renderChainBadge(canvas);

    canvas.restore();
  }

  /// 连锁序号徽章：卡片左上角的金色圆形序号（1/2/3/4…）。
  ///
  /// 连锁结束（快照序号变 null）后停留 [_chainLingerSeconds] 再按
  /// [_chainFadeSeconds] 淡出，淡出整体经 saveLayer 施加透明度。
  void _renderChainBadge(Canvas canvas) {
    final order = _chainBadgeOrder;
    if (order == null) return;

    var alpha = 1.0;
    final clearAt = _chainBadgeClearAt;
    if (clearAt != null) {
      final t = _time - clearAt;
      const total = _chainLingerSeconds + _chainFadeSeconds;
      if (t >= total) {
        _chainBadgeOrder = null;
        _chainBadgeClearAt = null;
        return;
      }
      if (t > _chainLingerSeconds) {
        alpha = 1.0 - (t - _chainLingerSeconds) / _chainFadeSeconds;
      }
    }

    // 卡片左上角压边：圆心落在槽位左上角点。
    final center = Offset(
      -DuelFieldLayout.slotWidth / 2,
      -DuelFieldLayout.slotHeight / 2,
    );
    const radius = 11.0;

    canvas.saveLayer(
      Rect.fromCircle(center: center, radius: radius + 6),
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    canvas.drawCircle(center, radius + 2, _chainBadgeGlowPaint);
    canvas.drawCircle(center, radius, _chainBadgeFillPaint);
    canvas.drawCircle(center, radius, _chainBadgeBorderPaint);
    _chainBadgeTextPaint.render(
      canvas,
      '$order',
      Vector2(center.dx, center.dy),
      anchor: Anchor.center,
    );
    canvas.restore();
  }

  /// 可召唤/可发动提醒角标：槽位右上角小红点（深色底圈 + 红色圆点）。
  /// 墓地/额外/除外槽位非怪兽区（不画 ATK/DEF 徽标），右上角无冲突。
  void _renderActivatableBadge(Canvas canvas) {
    final center = Offset(_cardRect.right - 6, _cardRect.top + 6);
    canvas.drawCircle(center, 5.5, _activatableDotBorderPaint);
    canvas.drawCircle(center, 4.0, _activatableDotPaint);
  }

  void _renderHighlight(Canvas canvas) {
    final isChecked = highlight == CardSlotHighlight.checked;
    final color = isChecked ? const Color(0xFFFFD700) : const Color(0xFF00F0FF);
    canvas.drawRRect(
      _highlightGlowRRect,
      _highlightGlowPaint..color = color.withValues(alpha: 0.45),
    );
    canvas.drawRRect(
      _highlightRRect,
      _highlightFillPaint
        ..color = color.withValues(alpha: isChecked ? 0.22 : 0.12),
    );
    canvas.drawRRect(
      _highlightRRect,
      _highlightStrokePaint
        ..color = color
        ..strokeWidth = isChecked ? 2.5 : 2.0,
    );
  }

  void _renderCardBody(Canvas canvas) {
    final pos = card!.position;
    final isFacedown = (pos & POS_FACEDOWN) != 0;
    final isDefense = (pos & POS_DEFENSE) != 0;

    // 守备表示：仅怪兽卡(CARD_ZONE_MZONE)横放；魔陷卡(CARD_ZONE_SZONE)始终竖放。
    // 魔陷无论盖牌(set)还是发动，卡片都保持竖方向。
    final isMonsterCard = card!.zone == CARD_ZONE_MZONE;
    final needsRotate = isDefense && isMonsterCard;

    canvas.save();
    if (needsRotate) {
      canvas.rotate(pi / 2);
      canvas.scale(0.74, 0.74);
    }

    if (isFacedown) {
      _renderCardBack(canvas);
    } else {
      _renderCardFace(canvas);
    }

    canvas.restore();

    // ATK/DEF 徽章：不受旋转影响，始终竖直显示在槽位右上角
    // 位置徽标：攻/守/里侧指示
    if (!isFacedown && isMonster) {
      _renderBadge(canvas, isDefense);
    }
  }

  /// 绘制卡背（里侧卡牌）。
  void _renderCardBack(Canvas canvas) {
    if (card?.zone == CARD_ZONE_DECK) {
      _renderDeckBack(canvas);
      return;
    }

    // 深蓝渐变背景
    canvas.drawRRect(_cardRRect, _cardBackPaint);

    // 中心圆环（青色边框）
    canvas.drawCircle(Offset.zero, 9, _cardBackRingPaint);
  }

  void _renderDeckBack(Canvas canvas) {
    canvas.drawRRect(_cardRRect, _deckBackPaint);

    canvas.save();
    canvas.clipRRect(_cardRRect);

    final rect = _cardRect;
    for (
    double x = rect.left - rect.height;
    x < rect.right + rect.height;
    x += 10
    ) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        _deckStripePaint,
      );
    }

    for (final radius in [12.0, 20.0, 29.0]) {
      canvas.drawCircle(
        Offset.zero,
        radius,
        _deckRingPaint..strokeWidth = radius == 29.0 ? 1.2 : 1.0,
      );
    }

    canvas.drawPath(_deckDiamondPath, _deckDiamondFillPaint);
    canvas.drawPath(_deckDiamondPath, _deckDiamondStrokePaint);

    canvas.restore();

    canvas.drawRRect(_cardRRect, _deckBorderPaint);
  }

  /// 绘制卡面（表侧卡牌）— 加载网络卡图，失败时显示占位。
  void _renderCardFace(Canvas canvas) {
    if (_cardImage != null) {
      // 绘制卡图（cover 方式裁剪到圆角矩形）
      final srcRect = Rect.fromLTWH(
        0,
        0,
        _cardImage!.width.toDouble(),
        _cardImage!.height.toDouble(),
      );
      canvas.save();
      canvas.clipRRect(_cardRRect);
      canvas.drawImageRect(_cardImage!, srcRect, _cardRect, _imagePaint);
      canvas.restore();

      // 白色边框
      canvas.drawRRect(_cardRRect, _faceBorderPaint);
    } else {
      // 占位：棕色背景 + code 文本
      canvas.drawRRect(_cardRRect, _facePlaceholderPaint);
      _codePaint.render(
        canvas,
        '${card!.code}',
        Vector2.zero(),
        anchor: Anchor.center,
      );
    }
  }

  /// 绘制 ATK/DEF 徽章 — 右上角，粉色 ATK / 青色 DEF。
  void _renderBadge(Canvas canvas, bool isDefense) {
    final value = isDefense ? card!.defense : card!.attack;
    final label = isDefense ? 'DEF' : 'ATK';
    final text = value == null ? label : '$label $value';
    final paint = isDefense ? _defBadgePaint : _atkBadgePaint;

    final metrics = paint.getLineMetrics(text);
    final badgeW = metrics.width + 8; // 4px 左右内边距
    const badgeH = 13.0;

    // 位置：槽位右上角，right: 3, top: 3
    final badgeX = DuelFieldLayout.slotWidth / 2 - 3 - badgeW;
    final badgeY = -DuelFieldLayout.slotHeight / 2 + 3;

    // 徽章矩形宽度随文本变化，保留在热路径分配（其余 Paint 已缓存）。
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeX, badgeY, badgeW, badgeH),
      const Radius.circular(4),
    );

    // 黑色半透明背景
    canvas.drawRRect(badgeRect, _badgeBgPaint);
    // 彩色边框
    canvas.drawRRect(
      badgeRect,
      isDefense ? _defBadgeBorderPaint : _atkBadgeBorderPaint,
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

  // 用 onTapUp 而非 onTapDown：引入双指捏合缩放（ScaleDetector）后，
  // tap recognizer 在手势竞技场中输给 scale 时只收到 onTapCancel——
  // 若按下即触发，双指操作的起始落点在卡槽上会误弹操作菜单。
  @override
  void onTapUp(TapUpEvent event) => onTap?.call();
}