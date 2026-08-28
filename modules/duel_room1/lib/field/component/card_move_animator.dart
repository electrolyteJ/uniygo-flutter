import 'package:biz/duel/models/field_zone_key.dart';
import 'package:biz/duel/models/card_move_event.dart';
import 'package:duelink/duelink.dart'
    show CARD_ZONE_HAND, CARD_ZONE_MZONE, CARD_ZONE_SZONE;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../duel_field_world.dart';
import '../models/card_move_geometry.dart';
import '../models/duel_field_layout.dart';
import 'card_flight_component.dart';

/// 卡片移动飞牌适配器（对照 SummonEffectAdapter 的 tick 范式）：
/// 监听快照的 cardMoveTick，把 biz 的 CardMoveEvent 翻译成
/// [CardFlightComponent] 飞行动画（挂 camera.viewport，屏幕空间）。
///
/// 覆盖方向（双向联动）：手牌↔墓地/除外、场上↔墓地/除外、场上↔手牌、
/// 卡组→墓地/除外（堆墓）等非抽卡移动；抽卡（卡组→手牌）保持走
/// 既有抽卡管线（biz 不为此类移动生成 CardMoveEvent）。
///
/// 同步语义（与抽卡一致）：飞行完成前目标位不显示该卡——场上目标经
/// [DuelFlameGame.concealedMoveTargetKeys] 隐藏（ZonesComponent 重建时
/// 跳过），手牌目标经 HandBarComponent.concealTrailing/reveal。
class CardMoveAnimator extends Component
    with HasWorldReference<DuelFieldWorld> {
  /// 移动飞牌比抽卡快：单张 0.5s，错位 0.12s。
  static const double movePerCardSeconds = 0.5;
  static const double moveStaggerSeconds = 0.12;

  int _lastTick = 0;

  @override
  void update(double dt) {
    super.update(dt);
    final snapshot = world.game.snapshot;
    final tick = snapshot.cardMoveTick;
    if (tick == _lastTick) return;
    _lastTick = tick;
    final event = snapshot.cardMoveEvent;
    // 同帧多条 MSG_MOVE 只见到最新一条（与 SummonEffectAdapter 同语义：
    // 中间的退化丢弃——黑洞类全场送墓的视觉表现为最后一张飞牌 +
    // 全场消失，可接受且不做队列积压）。
    if (event != null) _play(event);
  }

  void _play(CardMoveEvent event) {
    final game = world.game;
    final fromRect = _rectFor(
      event.fromController,
      event.fromLocation,
      event.fromSequence,
    );
    final toRect = _rectFor(
      event.toController,
      event.toLocation,
      event.toSequence,
    );
    if (fromRect == null || toRect == null) return; // 无法换算，跳过动画

    // 对方卡移动渲染卡背（隐私/视觉纪律）；code=0 占位恒卡背。
    final faceUp = cardMoveFaceUp(event, game.snapshot.myController);

    // 目标位隐藏（飞行完成前不显示）。
    final concealZoneKey = _concealFieldTarget(event);
    final handConceal = _concealHandTarget(event);

    late final CardFlightComponent flight;
    flight = CardFlightComponent(
      codes: [event.code],
      faceUp: faceUp,
      source: fromRect,
      targets: [toRect],
      cardSize: Size(
        DuelFieldLayout.slotWidth,
        DuelFieldLayout.slotHeight,
      ),
      perCardDuration: movePerCardSeconds,
      stagger: 0,
      onCardArrived: (_) {},
      onAllDone: () {
        game.moveFlights.remove(flight);
        if (concealZoneKey != null) {
          game.concealedMoveTargetKeys.remove(concealZoneKey);
          world.rebuildField();
        }
        handConceal?.call();
      },
    );
    game.moveFlights.add(flight);
    game.camera.viewport.add(flight);
  }

  /// 场上目标槽位（怪兽/魔陷/场地区）飞行期间隐藏：返回被隐藏的
  /// zoneKey（无需隐藏返回 null）。
  String? _concealFieldTarget(CardMoveEvent event) {
    if (event.toLocation &
            (CARD_ZONE_MZONE | CARD_ZONE_SZONE) ==
        0) {
      return null;
    }
    final key = zoneKeyOf(
      event.toController,
      event.toLocation,
      event.toSequence,
    );
    world.game.concealedMoveTargetKeys.add(key);
    world.rebuildField();
    return key;
  }

  /// 手牌目标：隐藏末尾新到卡，返回落地揭示回调（非手牌目标返回 null）。
  void Function()? _concealHandTarget(CardMoveEvent event) {
    if (event.toLocation & CARD_ZONE_HAND == 0) return null;
    final game = world.game;
    final isSelf = event.toController == game.snapshot.myController;
    final bar = isSelf ? game.selfHandBar : game.oppHandBar;
    if (bar == null) return null;
    final indices = bar.concealTrailing(1);
    if (indices.isEmpty) return null;
    return () {
      for (final i in indices) {
        bar.reveal(i);
      }
    };
  }

  /// 端点（controller/location/sequence）→ 屏幕矩形（视口坐标）。
  ///
  /// - 手牌：手牌栏卡位矩形（下标钳到当前手牌范围）；
  /// - 卡组：deckSlotWidgetRect；
  /// - 场上/墓地/除外/额外：棋盘板面坐标 → 投影 → widget 矩形；
  /// - 其它：null（跳过动画）。
  Rect? _rectFor(int controller, int location, int sequence) {
    final game = world.game;
    final myController = game.snapshot.myController;
    final isSelf = controller == myController;
    switch (moveEndpointSource(location)) {
      case MoveEndpointSource.handBar:
        final bar = isSelf ? game.selfHandBar : game.oppHandBar;
        if (bar == null) return null;
        final hand = isSelf ? game.snapshot.selfHand : game.snapshot.oppHand;
        if (hand.codes.isEmpty) return null;
        final index = sequence.clamp(0, hand.codes.length - 1);
        return bar.cardSlotRect(index);
      case MoveEndpointSource.deckSlot:
        return game.deckSlotWidgetRect(isSelf);
      case MoveEndpointSource.boardSlot:
        final boardPos = boardPosForCardLocation(
          controller: controller,
          location: location,
          sequence: sequence,
          myController: myController,
        );
        if (boardPos == null) return null;
        final zoom = game.camera.viewfinder.zoom;
        final center = game.worldToWidget(
          world.project3D(boardPos.dx, boardPos.dy),
        );
        return Rect.fromCenter(
          center: center,
          width: DuelFieldLayout.slotWidth * zoom,
          height: DuelFieldLayout.slotHeight * zoom,
        );
      case MoveEndpointSource.unresolvable:
        return null;
    }
  }
}
