import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../cardlive.dart';
import 'monster_catalog.dart';

/// 召唤动画鉴赏舞台：在右侧面板循环播放所选怪兽的 3D 召唤演出。
///
/// 与决斗场地的 [Summon3DOverlay] 不同：这里演出循环播放
/// （loop: true），换怪兽或点击重播时重建游戏实例。
class SummonStage extends StatefulWidget {
  const SummonStage({super.key, required this.monster});

  /// 当前展示的怪兽（决定 rig 配色）。
  final LiveMonster monster;

  @override
  State<SummonStage> createState() => _SummonStageState();
}

class _SummonStageState extends State<SummonStage> {
  Summon3DGame? _game;

  /// 每次重播/换怪兽自增，作为 GameWidget 的 key 强制重建。
  int _playToken = 0;

  /// glb 模型加载/解析期间显示 loading（程序化 rig 几乎瞬间就绪）。
  bool _loading = true;

  @override
  void didUpdateWidget(SummonStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.monster != widget.monster) _restart();
  }

  void _restart() {
    setState(() {
      _game = null;
      _playToken++;
      _loading = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final game = _game ??= Summon3DGame(
              // 略低于画面中心：龙身从目标点向上展开，整体居中。
              dragonTarget: Summon3DGame.screenToWorld(
                Offset(size.width / 2, size.height * 0.58),
                size,
              ),
              onDone: () {}, // loop 模式下不会触发
              loop: true,
              metalColor: widget.monster.metalColor,
              jointColor: widget.monster.jointColor,
              glowColor: widget.monster.glowColor,
              modelAsset: widget.monster.modelAsset,
              onReady: () {
                if (mounted) setState(() => _loading = false);
              },
            );
            return GameWidget(
              key: ValueKey('cardlive-stage-$_playToken'),
              game: game,
            );
          },
        ),
        // glb 加载/解析中的 loading 遮罩。
        if (_loading)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0C1424),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.tealAccent),
                    SizedBox(height: 14),
                    Text(
                      '3D 模型加载中…',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // 底部信息条：怪兽名 + 卡密 + 重播按钮。
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.75),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.monster.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.monster.accent.withValues(alpha: 0.8),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${widget.monster.name} · ${widget.monster.code}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '循环播放中',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const ValueKey('cardlive-stage-replay'),
                  tooltip: '重播',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.replay, color: Colors.white),
                  onPressed: _restart,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
