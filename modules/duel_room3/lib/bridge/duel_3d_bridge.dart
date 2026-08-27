import 'dart:ui' as ui;

import 'package:biz/duel/field/card_confirm_state.dart';
import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:duel_room3/scene3d/zone_grid_component.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math.dart';

import '../scene3d/card_standee.dart';
import '../scene3d/camera_rig.dart';
import '../scene3d/duel_3d_game.dart';
import '../scene3d/field_3d_layout.dart';
import 'field_3d_mapper.dart';

/// Riverpod 状态 → 3D 场景指令的桥接器。
///
/// 在房间页 initState 经 [attach] 挂接 listenManual 订阅，
/// 把 DuelFieldState 的快照 diff / tick 事件翻译成 Duel3DGame 指令：
/// - fieldCards → 立牌增删改
/// - summonEffectTick → 召唤特效 + 运镜 + 立牌登场
/// - drawAnimationTick → 抽牌飞牌
/// - selfLpEventId/opponentLpEventId → 伤害/回复数字 + 轻晃
/// - lastAttackFrom/To → 攻击前扑 + 命中爆发 + 震屏 + 高攻光束
/// - deckShuffleTick → 洗牌粒子
/// - selectWindowProvider → 地砖高亮（可选中/已勾选/放置目标）
class Duel3DBridge {
  Duel3DBridge({required this.game});

  final Duel3DGame game;

  final List<ProviderSubscription> _subs = [];

  /// 己方/对方 LP 数字的世界锚点（场地上方）。
  static final Vector3 selfLpAnchor = Vector3(2.6, 1.2, 4.0);
  static final Vector3 oppLpAnchor = Vector3(-2.6, 1.2, -4.0);

  void attach(WidgetRef ref) {
    _subs.addAll([
      ref.listenManual<DuelFieldState>(duelFieldProvider, _onFieldChanged),
      ref.listenManual(
        selectWindowProvider,
        (prev, next) => _syncHighlights(ref),
      ),
      ref.listenManual(
        cardConfirmProvider,
        (prev, next) => _syncHighlights(ref),
      ),
    ]);
  }

  void detach() {
    for (final sub in _subs) {
      sub.close();
    }
    _subs.clear();
  }

  // ───────────────────────── 场地快照 ─────────────────────────

  void _onFieldChanged(DuelFieldState? prev, DuelFieldState next) {
    // 立牌摆放
    game.standees.applySnapshot(mapFieldCards(next.fieldCards));

    // 召唤特效
    if (prev != null &&
        next.summonEffectTick != prev.summonEffectTick &&
        next.summonEffectEvent != null) {
      _playSummon(next);
    }

    // 抽牌
    if (prev != null &&
        next.drawAnimationTick != prev.drawAnimationTick &&
        next.drawAnimationEvent != null) {
      final event = next.drawAnimationEvent!;
      final isSelf = event.player == next.myController;
      final deckCenter = _slotGroundCenter(isSelf ? 'self_deck' : 'opp_deck');
      if (deckCenter != null) {
        for (var i = 0; i < event.codes.length; i++) {
          game.effects.playDrawFlight(deckCenter, toSelf: isSelf);
        }
      }
    }

    // LP 变化
    if (prev != null && next.selfLpEventId != prev.selfLpEventId) {
      final delta = next.selfLpDelta;
      game.effects.playDamageNumber(selfLpAnchor, delta.abs(), heal: delta > 0);
      game.cameraRig.shake(intensity: 0.12, duration: 0.3);
    }
    if (prev != null && next.opponentLpEventId != prev.opponentLpEventId) {
      final delta = next.opponentLpDelta;
      game.effects.playDamageNumber(oppLpAnchor, delta.abs(), heal: delta > 0);
      game.cameraRig.shake(intensity: 0.12, duration: 0.3);
    }

    // 攻击宣言
    if (prev != null &&
        next.lastAttackFrom != null &&
        (next.lastAttackFrom != prev.lastAttackFrom ||
            next.lastAttackTo != prev.lastAttackTo)) {
      _playAttack(next);
    }

    // 洗牌
    if (prev != null &&
        next.selfDeckShuffleTick != prev.selfDeckShuffleTick) {
      _playShuffle('self_deck');
    }
    if (prev != null &&
        next.oppDeckShuffleTick != prev.oppDeckShuffleTick) {
      _playShuffle('opp_deck');
    }
  }

  void _playSummon(DuelFieldState state) {
    final event = state.summonEffectEvent!;
    final fx = mapSummonFx(event.type);
    final ground = game.standees.slotGroundCenter(event.zoneKey);
    if (ground != null) {
      game.effects.playSummonFx(ground, fx);
    }
    // 立牌登场动画（快照已插入该卡，升级为对应入场）
    final standee = game.standees.at(event.zoneKey);
    if (standee != null) {
      final entrance = switch (event.type.name) {
        'flip' => StandeeEntrance.flip,
        'set' => StandeeEntrance.set,
        _ => StandeeEntrance.summon,
      };
      standee.playEntrance(entrance);
    }
    // 运镜：推近特写后回默认位
    if (ground != null) {
      game.cameraRig.flyTo(CameraShot(
        position: Vector3(ground.x * 0.5, 3.2, ground.z + 4.2),
        target: Vector3(ground.x, 0.6, ground.z),
        duration: 0.5,
      ));
      game.cameraRig.enqueue(CameraShot(
        position: Field3DLayout.defaultCameraPosition.clone(),
        target: Field3DLayout.defaultCameraTarget.clone(),
        duration: 0.8,
      ));
    }
  }

  void _playAttack(DuelFieldState state) {
    final fromKey = state.lastAttackFrom!;
    final toKey = state.lastAttackTo;
    final attacker = game.standees.at(fromKey);
    if (attacker == null) return;
    final targetPos = toKey != null
        ? game.standees.slotStandeeCenter(toKey)
        : null;
    // 直接攻击时冲向对方牌手锚点
    final impactPos = targetPos ?? Vector3(0, 1.0, -5.2);
    attacker.lunge(impactPos, onImpact: () {
      game.effects.playImpactFx(impactPos);
      game.cameraRig.shake(intensity: 0.22, duration: 0.4);
    });
    // 高攻怪追加光束
    final atkValue = state.fieldCards[fromKey]?.attack ?? 0;
    if (atkValue >= 2000) {
      final from = game.standees.slotStandeeCenter(fromKey);
      if (from != null) {
        game.effects.playBeamFx(from, impactPos);
      }
    }
  }

  void _playShuffle(String deckLabel) {
    final center = _slotGroundCenter(deckLabel);
    if (center != null) {
      game.effects.particles.burst(
        origin: center + Vector3(0, 0.2, 0),
        color: const ui.Color(0xFF9FE8FF),
        count: 14,
        speed: 1.6,
        life: 0.6,
      );
    }
  }

  Vector3? _slotGroundCenter(String slotLabel) {
    for (final slot in game.slots) {
      if (slot.label == slotLabel) return slot.center;
    }
    return null;
  }

  // ───────────────────────── 高亮同步 ─────────────────────────

  void _syncHighlights(WidgetRef ref) {
    final select = ref.read(selectWindowProvider);
    final selectN = ref.read(selectWindowProvider.notifier);
    final confirm = ref.read(cardConfirmProvider);

    game.zoneGrid.clearHighlights();

    final selectable = selectN.inlineSelectableFieldKeys;
    final checked = selectN.inlineSelectedFieldKeys;
    final placeTargets = select.placeTargetFieldKeys;
    final confirmed = confirm.confirmedFieldSlotKeys;

    for (final key in placeTargets) {
      game.zoneGrid.setSlotHighlight(key, SlotHighlight.placeTarget);
    }
    for (final key in selectable) {
      game.zoneGrid.setSlotHighlight(key, SlotHighlight.selectable);
    }
    for (final key in checked) {
      game.zoneGrid.setSlotHighlight(key, SlotHighlight.checked);
    }
    for (final key in confirmed) {
      game.zoneGrid.setSlotHighlight(key, SlotHighlight.checked);
    }

    // 立牌描边：可选中=青，已勾选=绿
    final field = ref.read(duelFieldProvider);
    for (final entry in field.fieldCards.entries) {
      final standee = game.standees.at(entry.key);
      if (standee == null) continue;
      if (checked.contains(entry.key) || confirmed.contains(entry.key)) {
        standee.setGlow(const ui.Color(0xFF7CFF6B));
      } else if (selectable.contains(entry.key)) {
        standee.setGlow(const ui.Color(0xFF37E2FF));
      } else {
        standee.setGlow(null);
      }
    }
  }
}
