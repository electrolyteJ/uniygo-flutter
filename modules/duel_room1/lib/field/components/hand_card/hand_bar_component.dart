import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../../duel_flame_game.dart';
import '../../util/hand_fan_layout.dart';
import 'hand.dart';
import 'hand_card_component.dart';

/// 手牌栏组件（Flame 版 HandCardsBar）：己方底部 / 对方顶部各一个实例，
/// 挂在 camera.viewport（屏幕空间，卡尺寸不随场地相机缩放）。
///
/// 职责：
/// - 按 [HandFanLayout] 扇形（凸弧 + 放射旋转 + 超宽重叠压缩）布设手牌；
/// - 快照差分更新（[applySnapshot]），不销毁重建，保留卡图缓存与动效；
/// - 洗牌动效（每卡随机横向偏移的往返摆动，同原 Flutter 版）；
/// - 抽卡/发牌飞行期间的逐张隐藏与落地揭示（[concealTrailing]/[reveal]）；
/// - 向 widget 层提供选中卡的屏幕矩形（Flutter 操作菜单锚定，拉式查询）。
///
/// 本组件以整个游戏画布为自身尺寸（position 恒为原点），
/// 子卡坐标 = 视口/屏幕坐标，与 DuelFlameGame.worldToWidget 同一空间。
class HandBarComponent extends PositionComponent
    with HasGameReference<DuelFlameGame> {
  HandBarComponent({
    required this.isSelfSide,
    this.onCardTap,
    this.onCardSecondaryTap,
  });

  /// 是否为己方（底部）手牌栏；false 为对方（顶部，不响应交互）。
  final bool isSelfSide;

  /// 点击手牌回调（index, code）；对方手牌栏为 null（不可交互）。
  final void Function(int index, int code)? onCardTap;

  /// 右键（辅助点击）手牌回调（index, code）；对方手牌栏为 null。
  final void Function(int index, int code)? onCardSecondaryTap;

  /// 对方手牌栏顶部 y（页面按 HUD 高度推入，见 [setHudTopY]）。
  double hudTopY = 0;

  /// 更新顶部 y 并重排手牌（值未变时跳过）。布局在 [_relayout] 中
  /// 读取 [hudTopY]，直接改字段不重排会让对方手牌栏停在旧位置。
  void setHudTopY(double y) {
    if (hudTopY == y) return;
    hudTopY = y;
    _relayout();
  }

  void relayout() => _relayout();

  /// 手牌栏整体是否可见（HUD 可见性跟随对局阶段：
  /// 猜拳/等待阶段场地页作背景时隐藏）。
  bool barVisible = false;

  final List<HandCardComponent> _cards = [];
  HandSnapshot _snap = const HandSnapshot.empty();
  int _lastShuffleTick = 0;

  /// 洗牌动效的每卡随机横向偏移（与 _cards 对齐）。
  List<double> _shuffleOffsets = const [];
  Effect? _shuffleFx;

  /// 抽卡/发牌动画期间处于隐藏态的手牌下标（飞行落地逐张揭示）。
  final Set<int> _concealed = {};

  HandCardComponent? _cardAt(Vector2 point) {
    if (!barVisible || !isSelfSide) return null;
    final minLocalExtent = 44 / game.hudScale;
    HandCardComponent? nearest;
    var nearestDistance = double.infinity;
    for (final card in _cards) {
      if (!card.primaryInteractive) continue;
      final dx = point.x - card.position.x;
      final dy = point.y - card.position.y;
      final distance = dx * dx + dy * dy;
      final visualRadius =
          math.sqrt(
            HandFanLayout.cardWidth * HandFanLayout.cardWidth +
                HandFanLayout.cardHeight * HandFanLayout.cardHeight,
          ) /
          2;
      final hitRadius = visualRadius > minLocalExtent / 2
          ? visualRadius
          : minLocalExtent / 2;
      if (distance > hitRadius * hitRadius) continue;
      if (distance < nearestDistance ||
          (distance == nearestDistance &&
              (nearest == null || card.priority > nearest.priority))) {
        nearest = card;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  bool dispatchPrimaryTap(Vector2 screenPoint) {
    final card = _cardAt(screenPoint / game.hudScale);
    if (card == null) return false;
    card.dispatchPrimaryTap();
    return true;
  }

  bool canDispatchPrimaryTap(Vector2 screenPoint) =>
      _cardAt(screenPoint / game.hudScale) != null;

  /// 手牌栏高度（与原 Flutter 版一致；虚拟坐标，屏显高度见
  /// [visualBarHeight]——紧凑 HUD 模式下整栏按 hudScale 缩放）。
  static const double barHeight = 96;

  /// 卡底与屏边的间距。
  static const double bottomPadding = 4;

  /// 手牌栏的屏幕像素高度（虚拟高度 × HUD 缩放）。
  double get visualBarHeight => barHeight * game.hudScale;

  /// 同步 HUD 缩放与虚拟尺寸。
  ///
  /// 整栏缩放经组件 transform 实现：布局在「虚拟视口」（屏寸 ÷ hudScale）
  /// 内按原 64×90 卡尺寸排布，再按 hudScale 整体缩放到屏幕——卡图、
  /// 扇形几何、上浮动效等全部沿用原数值，命中测试随变换自动适配。
  void _syncHudScale() {
    final hs = game.hudScale;
    scale = Vector2.all(hs);
    size.setFrom(game.size / hs);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _syncHudScale();
    // 可见性/挂载晚于首份快照时（页面监听注册早于游戏加载完成）补齐。
    barVisible = game.handBarsVisible;
    applySnapshot(isSelfSide ? game.snapshot.selfHand : game.snapshot.oppHand);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _syncHudScale();
    _relayout();
  }

  /// 快照差分更新：数量变化才增删子卡，其余原地更新。
  void applySnapshot(HandSnapshot snap) {
    _snap = snap;
    // 张数对齐：多退少补（抽/丢/回收都会改变张数）。
    while (_cards.length < snap.codes.length) {
      final card =
          HandCardComponent(index: _cards.length, isSelfSide: isSelfSide)
            ..onTapCard = onCardTap
            ..onSecondaryTapCard = onCardSecondaryTap;
      _cards.add(card);
      add(card);
    }
    while (_cards.length > snap.codes.length) {
      final card = _cards.removeLast();
      // 被移除卡的下标若处于隐藏态，一并清理。
      _concealed.remove(card.index);
      card.removeFromParent();
    }
    for (var i = 0; i < _cards.length; i++) {
      final card = _cards[i];
      card.updateContent(
        code: snap.codes[i],
        faceUp: snap.faceUp,
        selected: snap.selectedIndex == i,
        highlighted: snap.highlightedIndices.contains(i),
        checked: snap.checkedIndices.contains(i),
        dimmed:
            snap.highlightedIndices.isNotEmpty &&
            !snap.highlightedIndices.contains(i),
        chainOrder: snap.chainOrderByIndex[i],
      );
      // 隐藏态只随 conceal/reveal 变化（快照更新不重置）。
      card.concealed = _concealed.contains(i);
    }
    // 洗牌信号：变化且张数稳定（张数也变了说明是抽/丢引发的快照，
    // 原 Flutter 版同样以 tick 为准）时播放一次洗牌动效。
    if (snap.shuffleTick != _lastShuffleTick) {
      _lastShuffleTick = snap.shuffleTick;
      _startShuffle();
    }
    _relayout();
  }

  /// 扇形排布：每卡基准中心 + 放射角；下标大的压在上面（priority）。
  ///
  /// 全部在虚拟坐标（屏寸 ÷ hudScale）内计算：size 已是虚拟尺寸，
  /// 屏幕空间的 hudTopY / Home 指示条安全区按 hudScale 折算成虚拟值。
  void _relayout() {
    if (_cards.isEmpty) return;
    // 未挂载（测试/构造期快照预填）时无 game 可取，按缩放 1、无安全区
    // 兜底；挂载后 onLoad/onGameResize 会触发重排补齐。
    final hs = isMounted ? game.hudScale : 1.0;
    final safeRect = isMounted
        ? game.safeRect
        : Rect.fromLTWH(0, 0, size.x * hs, size.y * hs);
    final geometry = HandBarViewportGeometry.resolve(
      viewport: Size(size.x * hs, size.y * hs),
      safeRect: safeRect,
      hudScale: hs,
    );
    final layout = HandFanLayout(
      count: _cards.length,
      maxWidth: geometry.maxWidth,
    );
    // 与原 Flutter 版一致：96 高条带内底对齐（bottom padding 4），
    // 凸弧向上（对方栏同样向上，与历史视觉一致）。
    // 己方栏底让开 Home 指示条安全区（viewPadding.bottom）。
    final baseLineY = isSelfSide
        ? size.y -
              geometry.selfBottomInset -
              bottomPadding -
              HandFanLayout.cardHeight / 2
        : hudTopY / hs +
              barHeight -
              bottomPadding -
              HandFanLayout.cardHeight / 2;
    for (var i = 0; i < _cards.length; i++) {
      _cards[i].setBaseCenter(
        Vector2(
          geometry.centerX + layout.centerDx(i),
          baseLineY + layout.centerAt(i).dy,
        ),
        layout.angleAt(i),
      );
    }
  }

  /// 洗牌动效：每卡随机横向偏移（约 ±1.5 卡位）往返一次，500ms。
  void _startShuffle() {
    if (_cards.length < 2) return;
    final rnd = math.Random();
    _shuffleOffsets = List.generate(
      _cards.length,
      (_) => (rnd.nextDouble() * 2 - 1) * 108.0,
    );
    _shuffleFx?.removeFromParent();
    _shuffleFx = FunctionEffect<HandBarComponent>((target, progress) {
      // 0 → 1 → 0：先换位再回位。
      final s = math.sin(progress * math.pi);
      for (var i = 0; i < _cards.length; i++) {
        _cards[i].shuffleDx = i < _shuffleOffsets.length
            ? _shuffleOffsets[i] * s
            : 0.0;
        _cards[i].syncPosition();
      }
    }, CurvedEffectController(0.5, Curves.linear));
    add(_shuffleFx!);
  }

  // ── 抽卡/发牌飞行联动 ──

  /// 抽卡动画开始时隐藏末尾 [count] 张（新抽的卡总是追加在手牌末尾），
  /// 返回被隐藏的下标列表（飞行终点定位用）。
  List<int> concealTrailing(int count) {
    if (count <= 0 || _cards.isEmpty) return const [];
    final start = math.max(0, _cards.length - count);
    final indices = <int>[];
    for (var i = start; i < _cards.length; i++) {
      _concealed.add(i);
      _cards[i].concealed = true;
      indices.add(i);
    }
    return indices;
  }

  /// 飞行卡落地：揭示对应手牌。
  void reveal(int index) {
    if (!_concealed.remove(index)) return;
    if (index >= 0 && index < _cards.length) {
      _cards[index].concealed = false;
    }
  }

  /// 新对局/异常重置：揭示全部并清空隐藏记录。
  void revealAll() {
    _concealed.clear();
    for (final card in _cards) {
      card.concealed = false;
    }
  }

  /// 第 [index] 张卡的基准卡位矩形（视口/屏幕坐标，不含上浮动效），
  /// 抽卡/发牌飞行的终点。卡中心/baseCenter 是虚拟坐标，×hudScale
  /// 换算回屏幕。
  Rect cardSlotRect(int index) {
    final hs = game.hudScale;
    if (index < 0 || index >= _cards.length) {
      // 兜底：栏中央（理论上调用方按下标闭合，不会触达）。
      return Rect.fromCenter(
        center: Offset(
          size.x / 2 * hs,
          (isSelfSide ? size.y - 50 : hudTopY / hs + 50) * hs,
        ),
        width: HandFanLayout.cardWidth * hs,
        height: HandFanLayout.cardHeight * hs,
      );
    }
    final c = _cards[index].baseCenter;
    return Rect.fromCenter(
      center: Offset(c.x * hs, c.y * hs),
      width: HandFanLayout.cardWidth * hs,
      height: HandFanLayout.cardHeight * hs,
    );
  }

  /// 选中卡的屏幕矩形（含选中上浮与放大），供 Flutter 操作菜单锚定。
  /// 无选中或下标越界时返回 null。
  Rect? selectedCardRect() {
    final index = _snap.selectedIndex;
    if (index == null || index < 0 || index >= _cards.length) return null;
    final hs = game.hudScale;
    final card = _cards[index];
    final lifted = Offset(
      (card.baseCenter.x + card.shuffleDx) * hs,
      (card.baseCenter.y - HandFanLayout.activeLift) * hs,
    );
    return Rect.fromCenter(
      center: lifted,
      width: HandFanLayout.cardWidth * HandFanLayout.activeScale * hs,
      height: HandFanLayout.cardHeight * HandFanLayout.activeScale * hs,
    );
  }

  @override
  void renderTree(Canvas canvas) {
    // HUD 隐藏（等待室/猜拳阶段）时整栏不渲染、不接收事件。
    if (!barVisible) return;
    super.renderTree(canvas);
  }
}
