import 'package:flutter/material.dart';

import 'package:biz/duel/models/duel_menu.dart';
import 'package:biz/widgets/cyber_button.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:duel_room1/field/widgets/docked_panel_shell.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:duel_room1/platform/platform_adaptive.dart';

/// 区域标题查表（zoneKey → 显示名）。
const _zoneTitles = <String, String>{
  'self_grave': '己方墓地',
  'opp_grave': '对手墓地',
  'self_removed': '己方除外',
  'opp_removed': '对手除外',
  'self_extra': '己方额外',
  'opp_extra': '对手额外',
};

String _zoneTitle(String zoneKey) => _zoneTitles[zoneKey] ?? '区域详情';

/// 区域浏览面板：查看墓地/除外/额外卡组内容的**非模态**停靠面板。
///
/// 停靠几何与 chrome 见 [DockedPanelShell]，不带全屏遮罩：
/// - 面板外的点击穿透到场地——点卡弹菜单、点其他区域堆即切换浏览内容
///   （overlay 状态 openZoneBrowser 换 key 天然支持）；
/// - 关闭只走右上角 × 按钮（[onClose]）或动作执行后的状态清理；
/// - 面板内选中卡片实时联动左侧 inspector。
/// 可发动标记的统一强调色：琥珀金。
/// 面板 chrome / 选中态全部是青色，金色与其互补冲突，
/// 「可发动」信息才能从一片青里跳出来。
const activatableGold = Color(0xFFFFC400);

class ZoneBrowserPanel extends StatefulWidget {
  final String zoneBrowserKey;
  final List<ZoneBrowserCardEntry> cards;
  final int? selectedCardSequence;
  final void Function(int sequence, int code) onCardTap;
  final VoidCallback onClose;
  final String Function(int code)? cardNameBuilder;
  final List<ActionMenuEntry> selectedActions;

  /// 该区域服务端记录的卡片总数。
  /// 当列表为空但总数大于 0 时（例如对手额外卡组为里侧），
  /// 空态会提示“里侧不可见”而不是“没有卡片”。
  final int hiddenCount;

  /// 当前窗口下可发动/可召唤的卡位 sequence 集合
  /// （biz zoneBrowserActivatableSequencesProvider）：命中的 tile
  /// 左上角显示「可发动」标记。
  final Set<int> activatableSequences;

  const ZoneBrowserPanel({
    super.key,
    required this.zoneBrowserKey,
    required this.cards,
    required this.selectedCardSequence,
    required this.onCardTap,
    required this.onClose,
    this.cardNameBuilder,
    this.selectedActions = const [],
    this.hiddenCount = 0,
    this.activatableSequences = const {},
  });

  @override
  State<ZoneBrowserPanel> createState() => _ZoneBrowserPanelState();
}

class _ZoneBrowserPanelState extends State<ZoneBrowserPanel>
    with SingleTickerProviderStateMixin {
  /// 可发动卡金色光环的呼吸脉冲。整面板共享一个 controller——
  /// 无论几张卡可发动都只有一个动画控制器；没有可发动卡时
  /// 停表归零，不可发动 tile 不挂动画、零逐帧重建。
  late final AnimationController _glowController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    _syncGlow();
  }

  @override
  void didUpdateWidget(covariant ZoneBrowserPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncGlow();
  }

  void _syncGlow() {
    if (widget.activatableSequences.isNotEmpty) {
      if (!_glowController.isAnimating) {
        _glowController.repeat(reverse: true);
      }
    } else if (_glowController.isAnimating) {
      _glowController.stop();
      _glowController.value = 0;
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DockedPanelShell(
      title: _zoneTitle(widget.zoneBrowserKey),
      count: widget.cards.length,
      onClose: widget.onClose,
      titleSuffix: widget.activatableSequences.isEmpty
          ? null
          : _ActivatableCountChip(count: widget.activatableSequences.length),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _CardsGrid(
                cards: widget.cards,
                hiddenCount: widget.hiddenCount,
                selectedCardSequence: widget.selectedCardSequence,
                onCardTap: widget.onCardTap,
                cardNameBuilder: widget.cardNameBuilder,
                activatableSequences: widget.activatableSequences,
                glowPulse: _glowController,
              ),
            ),
            if (widget.selectedActions.isNotEmpty) ...[
              SizedBox(height: 8),
              _ActionsSection(actions: widget.selectedActions),
            ],
          ],
        ),
      ),
    );
  }
}

/// 卡片网格（或空态文案）。tile 以 sequence 为 key：区域内容变化时
/// 选中动画状态跟随卡走，不随下标错位。
///
/// 网格列数消费 [DuelRoomLayoutSpec]：compact 固定 2 列，
/// regular/wide 为 4 列，不以无限缩小 tile 换取固定列数。
/// tile 宽高比按「卡图实卡比例 59:86 + 8 间距 + 两行卡名 + 8 padding」
/// 反推 ≈ 0.59，保证卡图按宽度完整展示、不被 BoxFit.cover 裁剪。
class _CardsGrid extends StatelessWidget {
  static const double _gridAspect = 0.59;
  final List<ZoneBrowserCardEntry> cards;
  final int hiddenCount;
  final int? selectedCardSequence;
  final void Function(int sequence, int code) onCardTap;
  final String Function(int code)? cardNameBuilder;
  final Set<int> activatableSequences;

  /// 面板级共享的可发动光环脉冲（0→1→0 循环）。
  final Animation<double> glowPulse;

  const _CardsGrid({
    required this.cards,
    required this.hiddenCount,
    required this.selectedCardSequence,
    required this.onCardTap,
    required this.cardNameBuilder,
    required this.activatableSequences,
    required this.glowPulse,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Center(
        child: Text(
          hiddenCount > 0 ? '该区域有 $hiddenCount 张里侧卡片，无法查看' : '该区域当前没有卡片',
          style: TextStyle(
            color: DockedPanelShell.subtitle,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: 'Noto Sans SC',
          ),
        ),
      );
    }
    final spec = DuelRoomLayout.of(context);
    return GridView.builder(
      key: const ValueKey('zone-browser-grid'),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: spec.gridColumns,
        mainAxisSpacing: DockedPanelShell.gridSpacing,
        crossAxisSpacing: DockedPanelShell.gridSpacing,
        childAspectRatio: _gridAspect,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final entry = cards[index];
        return _ZoneBrowserCardTile(
          key: ValueKey(entry.sequence),
          code: entry.code,
          name: cardNameBuilder?.call(entry.code) ?? 'Card #${entry.code}',
          isSelected: selectedCardSequence == entry.sequence,
          isActivatable: activatableSequences.contains(entry.sequence),
          glowPulse: glowPulse,
          onTap: () => onCardTap(entry.sequence, entry.code),
        );
      },
    );
  }
}

/// 「可直接执行的动作」区：选中卡片后可触发的服务端动作。
class _ActionsSection extends StatelessWidget {
  final List<ActionMenuEntry> actions;

  const _ActionsSection({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '可直接执行的动作',
            style: TextStyle(
              color: DockedPanelShell.accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFamily: 'Orbitron',
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 10),
          ListView.separated(
            key: const ValueKey('zone-browser-actions-scroll'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            separatorBuilder: (_, _) => SizedBox(height: 8),
            itemBuilder: (context, index) => CyberButton(
              label: actions[index].label,
              width: double.infinity,
              onTap: actions[index].onTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneBrowserCardTile extends StatelessWidget {
  final int code;
  final String name;
  final bool isSelected;

  /// 当前窗口下该卡有可发动/可召唤动作（墓地诱发、额外特召等）。
  final bool isActivatable;

  /// 面板级共享的可发动光环脉冲（0→1→0 循环）。
  final Animation<double> glowPulse;
  final VoidCallback onTap;

  const _ZoneBrowserCardTile({
    super.key,
    required this.code,
    required this.name,
    required this.isSelected,
    required this.onTap,
    required this.glowPulse,
    this.isActivatable = false,
  });

  @override
  Widget build(BuildContext context) {
    // 只有可发动卡才挂脉冲动画：不可发动 tile 静态构建，
    // 不跟随动画逐帧重建。
    if (!isActivatable) return _buildTile(glow: 0);
    return AnimatedBuilder(
      animation: glowPulse,
      builder: (context, _) => _buildTile(glow: glowPulse.value),
    );
  }

  Widget _buildTile({required double glow}) {
    return ClickableCursor(
      child: HoverHighlight(
        hoverColor: Colors.white.withValues(alpha: 0.06),
        child: GestureDetector(
          onTap: onTap,
          // 外层容器承载金色呼吸光环：不进 AnimatedContainer，
          // 避免 180ms 隐式动画把脉冲追平成滞后的平滑跟随。
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: isActivatable
                  ? [
                      BoxShadow(
                        color: activatableGold.withValues(
                          alpha: 0.30 + 0.40 * glow,
                        ),
                        blurRadius: 10 + 16 * glow,
                        spreadRadius: 0.5 + 0.5 * glow,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isSelected ? 0.09 : 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  // 选中优先青色（交互反馈一致）；非选中的可发动卡金描边。
                  color: isSelected
                      ? DockedPanelShell.accent
                      : isActivatable
                      ? activatableGold
                      : Colors.white.withValues(alpha: 0.1),
                  width: isSelected
                      ? 1.6
                      : isActivatable
                      ? 1.5
                      : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: DockedPanelShell.accent.withValues(
                            alpha: 0.32,
                          ),
                          blurRadius: 24,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 卡图区：占据扣除卡名与间距后的剩余高度，BoxFit.contain
                  // 完整展示不裁剪（不再用固定 AspectRatio 撑高，避免 tile
                  // 高度不足时 Column 底部溢出）。width/height 仅作 CardImage
                  // 解码降采样目标，实际尺寸由 Expanded 的紧约束决定。
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CardImage(
                            code: code,
                            width: 160,
                            height: 233,
                            fit: BoxFit.contain,
                          ),
                          // 可发动标记：左上角小胶囊（与选中态的整框
                          // 描边区分，非选中也可辨识）。
                          if (isActivatable)
                            Positioned(
                              left: 3,
                              top: 3,
                              child: _ActivatableBadge(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFFD7E3F2),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Noto Sans SC',
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「可发动」角标：琥珀金胶囊 + 闪电图标，叠在卡图左上角。
/// 金色与面板青色 chrome 强对比，字号/内边距比旧版加大，
/// 保证 3 列网格缩略图上一眼可辨。
class _ActivatableBadge extends StatelessWidget {
  const _ActivatableBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: activatableGold,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: activatableGold.withValues(alpha: 0.65),
            blurRadius: 8,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, color: Colors.black, size: 10),
          SizedBox(width: 1),
          Text(
            '可发动',
            style: TextStyle(
              color: Colors.black,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              fontFamily: 'Noto Sans SC',
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// 标题栏「⚡ N 可发动」计数 chip：金框金字，在青色 chrome 的
/// 标题栏里一眼定位本区域有多少张卡可以行动。
class _ActivatableCountChip extends StatelessWidget {
  final int count;

  const _ActivatableCountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: activatableGold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: activatableGold, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, color: activatableGold, size: 12),
          SizedBox(width: 2),
          Text(
            '$count 可发动',
            style: TextStyle(
              color: activatableGold,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              fontFamily: 'Noto Sans SC',
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
