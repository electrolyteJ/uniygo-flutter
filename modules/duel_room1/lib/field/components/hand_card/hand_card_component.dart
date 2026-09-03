import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../duel_field_game.dart';
import '../../util/hand_fan_layout.dart';
import '../card_paint.dart';

/// 单张手牌组件（Flame 版 HandCardsBar 的卡件）。
///
/// 组合结构（均为本组件的子节点，随父级旋转/缩放/上浮一体变换）：
/// - [SpriteComponent] 卡体：卡面用 CardImageLoader 的 ui.Image，
///   卡背用 CardPaint.loadCardBackSprite 一次性烘焙的 Sprite；
/// - [_HandCardDressing] 前景装饰：描边/置灰/连锁序号徽章；
/// - 底层发光由本组件 render 绘制（先于子节点渲染，天然垫底）。
///
/// 交互与动效（hover/选中上浮 + 放大回弹）由本组件承担；
/// 位置由 HandBarComponent 经 [baseCenter] 布设。
class HandCardComponent extends PositionComponent
    with
        HoverCallbacks,
        SecondaryTapCallbacks,
        HasGameReference<DuelFieldGame> {
  HandCardComponent({required this.index, required this.isSelfSide})
    : super(
        size: Vector2(HandFanLayout.cardWidth, HandFanLayout.cardHeight),
        anchor: Anchor.center,
        // 扇形重叠排布：下标大的压在小的上面。
        priority: index,
      ) {
    // 子组件在构造期创建：手牌栏 add(本卡) 后同一帧就会 updateContent，
    // 等不到 onLoad；SpriteComponent 挂载时也要求 sprite 非空。
    _body = SpriteComponent(
      sprite: CardPaint.cardBackSprite(),
      size: size.clone(),
    );
    _dressing = _HandCardDressing(size: size.clone());
  }

  /// 手牌下标（排布与回调用）。
  final int index;

  /// 是否为己方（底部）手牌；对方手牌不响应任何交互。
  final bool isSelfSide;

  /// 扇形排布基准中心（bar 局部坐标 = 视口坐标）。
  ///
  /// 上浮/洗牌等动效只改 [_liftPx]/[shuffleDx]，再经 [_syncPosition]
  /// 合成最终 position，避免多个 Effect 直接互踩 position。
  Vector2 baseCenter = Vector2.zero();

  // ── 快照状态（updateContent 写入） ──
  int _code = 0;
  bool _faceUp = false;
  bool _selected = false;
  bool _highlighted = false;
  bool _checked = false;
  bool _dimmed = false;

  /// 抽卡/发牌飞行途中：卡尚未落地，不渲染也不响应交互。
  bool concealed = false;

  // ── 交互 ──
  bool _hovered = false;
  void Function(int index, int code)? onTapCard;
  void Function(int index, int code)? onSecondaryTapCard;

  // ── 动效 ──
  double _liftPx = 0;
  double shuffleDx = 0;
  Effect? _liftFx;
  Effect? _scaleFx;

  /// 上浮/放大动效曲线：与原 Flutter 版 AnimatedContainer 的
  /// cubic-bezier(0.34,1.56,0.64,1) 回弹一致。
  static final _bounceCurve = const Cubic(0.34, 1.56, 0.64, 1);

  // ── 子组件（构造期创建，见构造器注释） ──
  late final SpriteComponent _body;
  late final _HandCardDressing _dressing;

  // ── 卡图 ──
  ui.Image? _cardImage;
  bool _imageRequested = false;
  bool _disposed = false;

  // ── 绘制缓存（底层发光） ──
  // render 局部坐标系原点在组件左上角（anchor 只影响定位/变换轴心）。
  static final _glowRRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(
      -4,
      -4,
      HandFanLayout.cardWidth + 8,
      HandFanLayout.cardHeight + 8,
    ),
    const Radius.circular(8),
  );
  static final _glowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

  bool get _active => _selected || _hovered;

  @override
  void onLoad() {
    addAll([_body, _dressing]);
  }

  /// 快照差分更新（不销毁重建，保留卡图缓存与动效状态）。
  void updateContent({
    required int code,
    required bool faceUp,
    required bool selected,
    required bool highlighted,
    required bool checked,
    required bool dimmed,
    required int? chainOrder,
  }) {
    if (code != _code) {
      _code = code;
      _cardImage?.dispose();
      _cardImage = null;
      _imageRequested = false;
    }
    _faceUp = faceUp;
    _syncBodySprite();
    if (_selected != selected ||
        _highlighted != highlighted ||
        _checked != checked) {
      _selected = selected;
      _highlighted = highlighted;
      _checked = checked;
      _animateState();
    }
    _dimmed = dimmed;
    _dressingSync();
    _dressing.syncChainBadge(chainOrder);
    _requestCardImage();
  }

  /// 卡体 Sprite 切换：卡面（已加载卡图）/卡背（含卡图加载中占位）。
  void _syncBodySprite() {
    final image = _cardImage;
    _body.sprite = (_faceUp && _code > 0 && image != null)
        ? Sprite(image)
        : CardPaint.cardBackSprite();
  }

  /// 前景装饰（描边/置灰）状态同步。
  void _dressingSync() {
    _dressing
      ..borderColor = (_active || _highlighted || _checked)
          ? const Color(0xFF00F0FF)
          : const Color(0xFFFFD700)
      ..borderWidth = _checked ? 2.5 : 1.5
      ..dimmed = _dimmed;
  }

  /// 上浮/放大动效：从当前值起播，中途反向不跳变。
  void _animateState() {
    _liftFx?.removeFromParent();
    _scaleFx?.removeFromParent();
    final targetLift = _active
        ? HandFanLayout.activeLift
        : _highlighted
        ? HandFanLayout.highlightLift
        : 0.0;
    final targetScale = _active ? HandFanLayout.activeScale : 1.0;
    final startLift = _liftPx;
    _liftFx = FunctionEffect<HandCardComponent>(
      (target, progress) {
        target._liftPx = startLift + (targetLift - startLift) * progress;
        target._syncPosition();
      },
      CurvedEffectController(0.25, _bounceCurve),
    );
    _scaleFx = ScaleEffect.to(
      Vector2.all(targetScale),
      CurvedEffectController(0.25, _bounceCurve),
    );
    addAll([_liftFx!, _scaleFx!]);
  }

  void _syncPosition() {
    position.setFrom(baseCenter);
    position.x += shuffleDx;
    position.y -= _liftPx;
  }

  /// 洗牌/外部偏移变化后重算位置（baseCenter/angle 不变时调用）。
  void syncPosition() => _syncPosition();

  /// 布设扇形基准位置（含凸弧/旋转），由 HandBarComponent 排布调用。
  void setBaseCenter(Vector2 center, double fanAngle) {
    baseCenter.setFrom(center);
    angle = fanAngle;
    _syncPosition();
  }

  /// 表侧卡请求加载卡图：先查缓存，命中则同步换面，否则异步加载。
  void _requestCardImage() {
    if (!_faceUp || _code <= 0 || _imageRequested) return;
    _imageRequested = true;
    final code = _code;
    // 克隆持有：加载器 LRU 驱逐会 dispose 原图，长持有必须自持克隆。
    final cached = game.world.getCachedCardImage(code);
    if (cached != null) {
      _cardImage = cached.clone();
      _syncBodySprite();
      return;
    }
    game.world.loadCardImage(code).then((image) {
      // A→B 换卡竞态：慢请求返回时卡可能已换，仅当仍是同一张才采用。
      if (_disposed || _code != code) return;
      if (image != null) {
        _cardImage = image.clone();
        _syncBodySprite();
      } else {
        _imageRequested = false;
      }
    });
  }

  @override
  void onRemove() {
    _disposed = true;
    _cardImage?.dispose();
    _cardImage = null;
    super.onRemove();
  }

  // ── 交互（对方手牌与隐藏卡不响应） ──

  bool get _interactive => isSelfSide && !concealed && onTapCard != null;

  bool get primaryInteractive => _interactive;

  void dispatchPrimaryTap() => onTapCard?.call(index, _code);

  @override
  void onHoverEnter() {
    if (!_interactive) return;
    _hovered = true;
    _animateState();
  }

  @override
  void onHoverExit() {
    if (!_hovered) return;
    _hovered = false;
    _animateState();
  }

  /// 右键/辅助点击：桌面/Web 下打开手牌上下文菜单（检视/可用动作）。
  @override
  void onSecondaryTapUp(SecondaryTapUpEvent event) {
    if (!_interactive || !game.contextMenuEnabled) return;
    onSecondaryTapCard?.call(index, _code);
  }

  // ── 渲染（先于子节点：只画垫底发光）──

  @override
  void render(Canvas canvas) {
    if (concealed) return;
    // 子节点渲染时同样会因 concealed 被装饰层跳过——此处仅画底层发光。
    final glowColor = (_active || _highlighted || _checked)
        ? const Color(0xFF00F0FF).withValues(alpha: _checked ? 0.9 : 0.7)
        : Colors.black.withValues(alpha: 0.7);
    canvas.drawRRect(_glowRRect, _glowPaint..color = glowColor);
  }

  @override
  void renderTree(Canvas canvas) {
    // 隐藏卡整棵子树不渲染（含卡体与装饰）。
    if (concealed) return;
    super.renderTree(canvas);
  }
}

/// 手牌前景装饰：描边/置灰/连锁序号徽章（卡体 SpriteComponent 之上）。
class _HandCardDressing extends PositionComponent {
  _HandCardDressing({required Vector2 size})
    : super(size: size, anchor: Anchor.topLeft);

  Color borderColor = const Color(0xFFFFD700);
  double borderWidth = 1.5;
  bool dimmed = false;

  // ── 连锁序号徽章（停留 1s + 淡出 0.3s，逻辑同 CardSlotComponent） ──
  int? _chainBadgeOrder;
  double? _chainBadgeClearAt;
  double _time = 0;
  static const _chainLingerSeconds = 1.0;
  static const _chainFadeSeconds = 0.3;

  late final RRect _cardRRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, size.x, size.y),
    const Radius.circular(5),
  );
  static final _borderPaint = Paint()..style = PaintingStyle.stroke;
  static final _dimPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.55);
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

  /// 连锁序号状态迁移：新序号立即展示/更新；变 null（连锁结束）时
  /// 记录清除时刻，由 render 停留 1s 后淡出；期间来了新序号立即恢复。
  void syncChainBadge(int? chainOrder) {
    if (chainOrder != null) {
      if (_chainBadgeOrder == null) _time = 0;
      _chainBadgeOrder = chainOrder;
      _chainBadgeClearAt = null;
    } else if (_chainBadgeOrder != null && _chainBadgeClearAt == null) {
      _chainBadgeClearAt = _time;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_chainBadgeOrder != null) _time += dt;
  }

  @override
  void render(Canvas canvas) {
    // 1. 描边：默认金，激活/高亮/勾选青（勾选加粗）。
    canvas.drawRRect(
      _cardRRect,
      _borderPaint
        ..color = borderColor
        ..strokeWidth = borderWidth,
    );

    // 2. 就地选择中非高亮卡置灰。
    if (dimmed) {
      canvas.drawRRect(_cardRRect, _dimPaint);
    }

    // 3. 连锁序号徽章：左上角压边金圆徽。
    _renderChainBadge(canvas);
  }

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

    const radius = 11.0;
    const center = Offset(0, 0);
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
}
