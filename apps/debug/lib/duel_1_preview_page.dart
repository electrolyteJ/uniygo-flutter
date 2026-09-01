// duel_room1 2D 场地调试预览页：不连服务器，直接摆 mock 场卡 + 手牌，
// 并通过快照信号触发召唤特效 / LP 变动等表现层演出。
//
// 用途：1) 无服务器验收 2D 场地渲染与沉浸式相机；2) 表现层调参。
import 'package:biz/duel/models/field_card.dart';
import 'package:biz/duel/models/lp_change_event.dart';
import 'package:biz/duel/models/summon_effect_event.dart';
import 'package:duel_room1/field/components/hand_card/hand.dart';
import 'package:duel_room1/field/duel_flame_game.dart';
import 'package:duel_room1/field/models/flame_field_snapshot.dart';
import 'package:duelink/duelink.dart' show DuelPhase;
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';

/// 2D 场地调试预览页（duel_room1）。
class Duel1PreviewPage extends StatefulWidget {
  const Duel1PreviewPage({super.key});

  @override
  State<Duel1PreviewPage> createState() => _Duel1PreviewPageState();
}

class _Duel1PreviewPageState extends State<Duel1PreviewPage> {
  late final DuelFlameGame _game;

  // 一些有代表性的卡号（青眼白龙/黑魔导/电子龙/黑魔术少女等）。
  static const _demoCodes = [89631139, 46986414, 70095154, 70781052, 23995346];

  // 表示形式位标志（与 duelink POS_* 一致）：表侧攻击 / 表侧守备 / 里侧守备。
  static const _posAtk = 0x1;
  static const _posDef = 0x4;
  static const _posSet = 0x8;

  // 区域位标志（与 duelink LOCATION_* 一致）：怪兽区 / 魔陷区。
  static const _zoneMonster = 0x04;
  static const _zoneSpellTrap = 0x08;

  // 场上卡（key = controller_zone_sequence）。
  static const _fieldCards = <String, FieldCard>{
    '0_4_0': FieldCard(
      code: 89631139, controller: 0, zone: _zoneMonster, sequence: 0,
      position: _posAtk, attack: 3000, defense: 2500, name: '青眼白龙',
    ),
    '0_4_1': FieldCard(
      code: 46986414, controller: 0, zone: _zoneMonster, sequence: 1,
      position: _posDef, attack: 2500, defense: 2100, name: '黑魔导',
    ),
    '0_4_2': FieldCard(
      code: 70095154, controller: 0, zone: _zoneMonster, sequence: 2,
      position: _posAtk, attack: 2100, defense: 1600, name: '电子龙',
    ),
    '0_8_1': FieldCard(
      code: 70781052, controller: 0, zone: _zoneSpellTrap, sequence: 1,
      position: _posSet, name: '盖卡',
    ),
    '1_4_0': FieldCard(
      code: 23995346, controller: 1, zone: _zoneMonster, sequence: 0,
      position: _posAtk, attack: 2500, defense: 2100, name: '黑魔术少女',
    ),
    '1_4_2': FieldCard(
      code: 89631139, controller: 1, zone: _zoneMonster, sequence: 2,
      position: _posDef, attack: 3000, defense: 2500, name: '青眼白龙',
    ),
    '1_8_0': FieldCard(
      code: 46986414, controller: 1, zone: _zoneSpellTrap, sequence: 0,
      position: _posSet, name: '盖卡',
    ),
  };

  // 己方手牌（明牌展示卡图）。
  static const _selfHand = HandSnapshot(
    codes: [89631139, 46986414, 70095154, 70781052, 23995346],
    faceUp: true,
    selectedIndex: null,
    highlightedIndices: {},
    checkedIndices: {},
    chainOrderByIndex: {},
    shuffleTick: 0,
  );

  // 对方手牌（卡背，codes 为 0 占位，长度即张数）。
  static const _oppHand = HandSnapshot(
    codes: [0, 0, 0, 0],
    faceUp: false,
    selectedIndex: null,
    highlightedIndices: {},
    checkedIndices: {},
    chainOrderByIndex: {},
    shuffleTick: 0,
  );

  int _summonTick = 0;
  int _lpTick = 0;
  int _selfLp = 8000;

  @override
  void initState() {
    super.initState();
    _game = DuelFlameGame();
    // 等 FlameGame onLoad 完成（场地组件挂载）后摆牌。
    _game.loaded.then((_) {
      if (!mounted) return;
      _game.applySnapshot(_buildSnapshot());
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 组装状态快照。[summonTick]/[summonEvent]/[lpTick]/[lpEvent]/[selfLp]
  /// 用于按钮触发时覆盖对应信号（tick 自增即触发表现层播放一次）。
  FlameFieldSnapshot _buildSnapshot({
    int? summonTick,
    SummonEffectEvent? summonEvent,
    int? lpTick,
    LpChangeEvent? lpEvent,
    int? selfLp,
  }) {
    return FlameFieldSnapshot(
      fieldCards: _fieldCards,
      myController: 0,
      phase: DuelPhase.m1,
      inDamageStep: false,
      battlePresentation: null,
      selfDeckShuffleTick: 0,
      oppDeckShuffleTick: 0,
      selfExtraShuffleTick: 0,
      oppExtraShuffleTick: 0,
      summonEffectTick: summonTick ?? _summonTick,
      summonEffectEvent: summonEvent,
      selfDeck: 34,
      oppDeck: 35,
      zoneCodes: const {},
      inlineSelectedFieldKeys: const {},
      inlineSelectableFieldKeys: const {},
      placeTargetFieldKeys: const {},
      activatableZoneKeys: const {},
      chainOrderBySlotKey: const {},
      selfHand: _selfHand,
      oppHand: _oppHand,
      turnCount: 3,
      currentPlayer: 0,
      selfTimeLeft: 240,
      opponentTimeLeft: 240,
      selfLp: selfLp ?? _selfLp,
      opponentLp: 8000,
      selfExtra: 5,
      oppExtra: 5,
      selfGrave: 3,
      oppGrave: 2,
      selfRemoved: 1,
      oppRemoved: 0,
      selfName: '青眼 (我)',
      oppName: '黑魔导 (对手)',
      lpChangeTick: lpTick ?? _lpTick,
      lpChangeEvent: lpEvent,
    );
  }

  void _playSummon() {
    setState(() => _summonTick++);
    _game.applySnapshot(
      _buildSnapshot(
        summonTick: _summonTick,
        summonEvent: SummonEffectEvent(
          id: _summonTick,
          code: _demoCodes[2],
          zoneKey: '0_4_3',
          type: SummonEffectType.normal,
        ),
      ),
    );
  }

  void _playSpecialSummon() {
    setState(() => _summonTick++);
    _game.applySnapshot(
      _buildSnapshot(
        summonTick: _summonTick,
        summonEvent: SummonEffectEvent(
          id: _summonTick,
          code: _demoCodes[3],
          zoneKey: '0_4_4',
          type: SummonEffectType.synchro,
        ),
      ),
    );
  }

  void _playDamage() {
    setState(() {
      _lpTick++;
      _selfLp -= 800;
    });
    _game.applySnapshot(
      _buildSnapshot(
        lpTick: _lpTick,
        lpEvent: LpChangeEvent(
          player: 0,
          delta: -800,
          kind: LpChangeKind.damage,
        ),
        selfLp: _selfLp,
      ),
    );
  }

  void _reset() {
    setState(() {
      _summonTick = 0;
      _lpTick = 0;
      _selfLp = 8000;
    });
    _game.applySnapshot(_buildSnapshot());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1220),
      appBar: AppBar(
        title: const Text('2D 场地预览（duel_room1）'),
        backgroundColor: const Color(0xFF0C1220),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(game: _game),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewButton(label: '召唤特效', onTap: _playSummon),
                  _PreviewButton(label: '同调召唤特效', onTap: _playSpecialSummon),
                  _PreviewButton(label: 'LP 伤害 -800', onTap: _playDamage),
                  _PreviewButton(label: '重置', onTap: _reset),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewButton extends StatelessWidget {
  const _PreviewButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A55),
          foregroundColor: Colors.white,
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}
