import 'package:duel_room1/field/components/zone/slot.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:biz/duel/models/field_card.dart';
import 'package:duel_room1/field/models/flame_field_snapshot.dart';
import 'package:duel_room1/field/components/zone/zone_slot_spec.dart';
import 'package:duel_room1/field/duel_field_world.dart';
import '../deck_shuffle_effect.dart';

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

  // 洗牌动效按侧各自跟踪（快照里是每侧独立 tick）：双方洗牌消息
  // 同帧到达时两侧的动效都要播放，不能互相吞掉。
  int _lastSelfDeckShuffleTick = 0;
  int _lastOppDeckShuffleTick = 0;
  int _lastSelfExtraShuffleTick = 0;
  int _lastOppExtraShuffleTick = 0;

  /// 当前状态快照（widget 层经游戏推入）。
  FlameFieldSnapshot get _snapshot => world.game.snapshot;

  ZonesComponent({this.onCardSelect, this.onZoneInspect, this.onPlaceSlotTap});

  CardSlotComponent? _slotAt(Vector2 point) {
    final zoom = world.game.camera.viewfinder.zoom;
    if (zoom <= 0) return null;
    final minWorldExtent = 44 / zoom;
    CardSlotComponent? nearest;
    var nearestDistance = double.infinity;
    for (final slot in _slots) {
      if (slot.onTap == null) continue;
      final dx = point.x - slot.position.x;
      final dy = point.y - slot.position.y;
      final halfWidth = (84.0 > minWorldExtent ? 84.0 : minWorldExtent) / 2;
      final halfHeight = (100.0 > minWorldExtent ? 100.0 : minWorldExtent) / 2;
      if (dx.abs() > halfWidth || dy.abs() > halfHeight) continue;
      final distance = dx * dx + dy * dy;
      if (distance < nearestDistance) {
        nearest = slot;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  bool dispatchPrimaryTap(Vector2 worldPoint) {
    final slot = _slotAt(worldPoint);
    if (slot == null) return false;
    slot.onTap?.call();
    return true;
  }

  bool canDispatchPrimaryTap(Vector2 worldPoint) => _slotAt(worldPoint) != null;

  @override
  void onMount() {
    super.onMount();
    // 热重载重建（DuelFieldWorld.reload）时游标从当前快照续起，
    // 避免把重建前最后一次洗牌动效重播一次。
    _lastSelfDeckShuffleTick = _snapshot.selfDeckShuffleTick;
    _lastOppDeckShuffleTick = _snapshot.oppDeckShuffleTick;
    _lastSelfExtraShuffleTick = _snapshot.selfExtraShuffleTick;
    _lastOppExtraShuffleTick = _snapshot.oppExtraShuffleTick;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _syncParallax();
    _spawnShuffleEffects();
  }

  /// 监听主卡组/额外卡组洗切信号（每侧独立 tick），在对应槽位播放动效。
  ///
  /// 落点取自 [DuelFieldLayout.deckSlotPos]/[DuelFieldLayout.extraSlotPos]，
  /// 与 buildZoneSlotSpecs 的 DECK/EXTRA 槽位一致（shuffle_slot_test 锁定）。
  void _spawnShuffleEffects() {
    final snapshot = _snapshot;
    if (snapshot.selfDeckShuffleTick != _lastSelfDeckShuffleTick) {
      _lastSelfDeckShuffleTick = snapshot.selfDeckShuffleTick;
      _spawnShuffleAt(DuelFieldLayout.deckSlotPos(isSelf: true));
    }
    if (snapshot.oppDeckShuffleTick != _lastOppDeckShuffleTick) {
      _lastOppDeckShuffleTick = snapshot.oppDeckShuffleTick;
      _spawnShuffleAt(DuelFieldLayout.deckSlotPos(isSelf: false));
    }
    if (snapshot.selfExtraShuffleTick != _lastSelfExtraShuffleTick) {
      _lastSelfExtraShuffleTick = snapshot.selfExtraShuffleTick;
      _spawnShuffleAt(DuelFieldLayout.extraSlotPos(isSelf: true));
    }
    if (snapshot.oppExtraShuffleTick != _lastOppExtraShuffleTick) {
      _lastOppExtraShuffleTick = snapshot.oppExtraShuffleTick;
      _spawnShuffleAt(DuelFieldLayout.extraSlotPos(isSelf: false));
    }
  }

  void _spawnShuffleAt(Offset boardPos) {
    world.add(
      DeckShuffleEffect(position: world.project3D(boardPos.dx, boardPos.dy)),
    );
  }

  /// 鼠标移动时重新投影卡槽位置（BoardMesh / PhaseLamp 每帧自行投影，无需同步）。
  void _syncParallax() {
    // 3D 投影临时关闭期间 project3D 为恒等变换：每次鼠标移动给 32 个槽位
    // 重赋相同位置是纯浪费，直接跳过。
    if (!world.isProjectionEnabled) return;
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
    final VoidCallback? onTap = switch (spec.tapBehavior) {
      ZoneSlotTapBehavior.inspect => () => onZoneInspect?.call(
        spec.inspectZoneKey!,
      ),
      ZoneSlotTapBehavior.none => null,
      // 放置目标优先；默认点卡分发读取 slot.card 当前值，
      // 避免闭包捕获过期卡片。
      ZoneSlotTapBehavior.select =>
        interaction.placeTargetKey != null
            ? () => onPlaceSlotTap?.call(interaction.placeTargetKey!)
            : () => onCardSelect?.call(slot.card, slot.card?.code),
    };
    // 移动飞牌期间目标槽位先不显示该卡（飞行落地后解除隐藏并重建）。
    final concealed = world.game.concealedMoveTargetKeys;
    slot.updateContent(
      card: spec.slotKeys.any(concealed.contains)
          ? null
          : spec.resolveCard(snapshot),
      highlight: interaction.highlight,
      onTap: onTap,
      activatable:
          spec.inspectZoneKey != null &&
          snapshot.activatableZoneKeys.contains(spec.inspectZoneKey),
      chainOrder: spec.chainOrderOf(snapshot.chainOrderBySlotKey),
    );
  }
}
