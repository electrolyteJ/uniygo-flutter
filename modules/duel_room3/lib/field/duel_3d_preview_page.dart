import 'dart:async';
import 'dart:math' as math;

import 'package:duel_room3/scene3d/fx/effects_manager.dart';
import 'package:vector_math/vector_math.dart' hide Colors;
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';

import '../hud/hud_theme.dart';
import '../scene3d/duel_3d_game.dart';
import '../scene3d/field_3d_layout.dart';
import '../scene3d/standee_diff.dart';

/// 3D 场景调试预览页：不连服务器，直接摆 mock 立牌 + 触发全套效果。
///
/// 用途：1) 无服务器验收 3D 渲染；2) 效果调参。
class Duel3DPreviewPage extends StatefulWidget {
  const Duel3DPreviewPage({super.key});

  @override
  State<Duel3DPreviewPage> createState() => _Duel3DPreviewPageState();
}

class _Duel3DPreviewPageState extends State<Duel3DPreviewPage> {
  late final Duel3DGame _game;

  // 一些有代表性的卡号（青眼白龙/黑魔导/电子龙等）
  static const _demoCodes = [89631139, 46986414, 70095154, 70781052, 23995346];

  bool _gpuReady = false;

  @override
  void initState() {
    super.initState();
    _game = Duel3DGame(myController: 0);
    // 先等 GpuBackend（shader 预载）就绪再挂载 GameWidget，
    // 再等场景装配完成（game.loaded）后摆牌。
    Duel3DGame.ensureGpuBackend().then((_) async {
      if (!mounted) return;
      setState(() => _gpuReady = true);
      await _game.loaded;
      _seedMockField();
      _startAutoDemo();
    });
  }

  /// 自动循环演出（预览页默认开启，便于截图/演示验收）。
  Timer? _autoDemo;
  int _demoStep = 0;

  void _startAutoDemo() {
    const steps = <String>['summon', 'attack', 'damage', 'draw'];
    _autoDemo?.cancel();
    _autoDemo = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted) return;
      switch (steps[_demoStep % steps.length]) {
        case 'summon':
          _playSummon();
        case 'attack':
          _playAttack();
        case 'damage':
          _playDamage();
        case 'draw':
          _playDraw();
      }
      _demoStep++;
    });
  }

  @override
  void dispose() {
    _autoDemo?.cancel();
    super.dispose();
  }

  void _seedMockField() {
    if (!mounted) return;
    _game.standees.applySnapshot({
      '0_4_0': StandeeCardView(
        zoneKey: '0_4_0',
        code: _demoCodes[0],
        position: posFaceupAttack,
      ),
      '0_4_1': StandeeCardView(
        zoneKey: '0_4_1',
        code: _demoCodes[1],
        position: posFaceupAttack,
        overlayCount: 2,
      ),
      '0_8_1': StandeeCardView(
        zoneKey: '0_8_1',
        code: _demoCodes[2],
        position: posFacedownDefense,
      ),
      '1_4_0': StandeeCardView(
        zoneKey: '1_4_0',
        code: _demoCodes[3],
        position: posFaceupAttack,
      ),
      '1_4_2': StandeeCardView(
        zoneKey: '1_4_2',
        code: _demoCodes[4],
        position: posFaceupDefense,
      ),
      '1_4_6': StandeeCardView(
        zoneKey: '1_4_6',
        code: _demoCodes[0],
        position: posFaceupAttack,
      ),
    });
  }

  void _playSummon() {
    final rng = math.Random();
    final fx = SummonFx.values[rng.nextInt(SummonFx.values.length)];
    final slot = _game.slots.firstWhere((s) => s.label == 'self_m_3');
    _game.effects.playSummonFx(slot.center, fx);
    _game.cameraRig.shake(intensity: 0.1, duration: 0.3);
  }

  void _playAttack() {
    final attacker = _game.standees.at('0_4_0');
    final target = _game.standees.slotStandeeCenter('1_4_0');
    if (attacker == null || target == null) return;
    attacker.lunge(target, onImpact: () {
      _game.effects.playImpactFx(target);
      _game.cameraRig.shake(intensity: 0.22, duration: 0.4);
    });
    final from = _game.standees.slotStandeeCenter('0_4_0');
    if (from != null) _game.effects.playBeamFx(from, target);
  }

  void _playDamage() {
    _game.effects.playDamageNumber(Vector3(-2.6, 1.2, -4.0), 2300);
    _game.effects.playDamageNumber(Vector3(2.6, 1.2, 4.0), 500, heal: true);
  }

  void _playDraw() {
    final deck = _game.slots.firstWhere((s) => s.label == 'self_deck');
    _game.effects.playDrawFlight(deck.center, toSelf: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HudTheme.bgDeep,
      appBar: AppBar(
        title: const Text('3D 场景预览（duel_room3）'),
        backgroundColor: const Color(0xFF0C1220),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_gpuReady)
            GameWidget(game: _game)
          else
            const Center(
              child: CircularProgressIndicator(color: HudTheme.cyan),
            ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: HudTheme.panel(radius: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewButton(label: '召唤特效', onTap: _playSummon),
                  _PreviewButton(label: '攻击+光束', onTap: _playAttack),
                  _PreviewButton(label: '伤害/回复数字', onTap: _playDamage),
                  _PreviewButton(label: '抽牌飞牌', onTap: _playDraw),
                  _PreviewButton(
                    label: '回默认机位',
                    onTap: _game.cameraRig.flyHome,
                  ),
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
        style: FilledButton.styleFrom(backgroundColor: HudTheme.cyanDim),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}
