import 'package:cardlive/src/summon_stage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'monster_catalog.dart';


/// 怪兽召唤动画鉴赏页：左侧怪兽列表，右侧 3D 召唤动画舞台。
///
/// 点击左侧怪兽，右侧循环播放其召唤演出（同一套程序化机械龙 rig
/// 按怪兽换色）。flame_3d 依赖 Flutter GPU，Web 不支持时降级提示。
class CardLivePage extends StatefulWidget {
  const CardLivePage({super.key});

  @override
  State<CardLivePage> createState() => _CardLivePageState();
}

class _CardLivePageState extends State<CardLivePage> {
  LiveMonster _selected = monsterCatalog.first;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      backgroundColor: const Color(0xFF0C1424),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          // 经 go_router 声明式回退：入口是 context.go('/card-live')（替换
          // 路由栈），原始 Navigator.pop 会 pop 掉栈内最后一条路由，
          // 与 go_router 同帧重建兜底栈冲突（Navigator dispose 时 locked）。
          onPressed: () => context.go('/'),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_filter, color: Colors.tealAccent),
            SizedBox(width: 8),
            Text('怪兽动画'),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: kIsWeb
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '3D 召唤演出需要 Flutter GPU，暂不支持 Web 平台。\n'
                    '请在桌面/移动端运行查看。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              )
            : narrow
            ? Column(
                children: [
                  SizedBox(height: 230, child: _buildMonsterList()),
                  const Divider(height: 1, color: Color(0xFF22304A)),
                  Expanded(child: SummonStage(monster: _selected)),
                ],
              )
            : Row(
                children: [
                  SizedBox(width: 300, child: _buildMonsterList()),
                  const VerticalDivider(width: 1, color: Color(0xFF22304A)),
                  Expanded(child: SummonStage(monster: _selected)),
                ],
              ),
      ),
    );
  }

  Widget _buildMonsterList() {
    return Container(
      color: const Color(0xFF101B30),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: monsterCatalog.length,
        itemBuilder: (context, index) {
          final monster = monsterCatalog[index];
          final selected = monster == _selected;
          return _MonsterTile(
            monster: monster,
            selected: selected,
            onTap: () => setState(() => _selected = monster),
          );
        },
      ),
    );
  }
}

class _MonsterTile extends StatelessWidget {
  final LiveMonster monster;
  final bool selected;
  final VoidCallback onTap;

  const _MonsterTile({
    required this.monster,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected
            ? monster.accent.withValues(alpha: 0.14)
            : const Color(0xFF182741),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey('cardlive-monster-${monster.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? monster.accent
                    : Colors.white.withValues(alpha: 0.06),
                width: selected ? 1.4 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: monster.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.smart_toy_outlined,
                    color: monster.accent,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monster.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        monster.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.play_circle_fill, color: monster.accent, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
