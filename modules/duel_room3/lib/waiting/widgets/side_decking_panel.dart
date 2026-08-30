import 'package:biz/duel/room/duel_room_state.dart' show SidingZone;
import 'package:flutter/material.dart';
import 'package:resource_data/card_info.dart' show CardInfo;

import '../../hud/hud_theme.dart';

/// 换备面板（match 模式局间换 Side Deck），交互与文案对齐 duel_room1，
/// 外观改用 HudTheme 赛博暗色主题。
///
/// 展示 + 回调：换备构成、基准数量与全部操作由 [DuelRoomNotifier] 驱动；
/// 本组件仅持有「确认提交中」的本地防抖标记。
///
/// 交互约定（YGOPro 换备规则）：
/// - 主卡组卡片点击后移入副卡组；额外卡组卡片点击后移入副卡组；
/// - 副卡组卡片提供「→主」「→额」两个按钮选择去向
///   （「→额」仅对额外卡组类型——融合/同调/超量/连接——显示）；
/// - 主卡组 ↔ 额外卡组之间不允许直接交换；
/// - 各分区数量与基准一致时「确认换备」才可点击。
class SideDeckingPanel extends StatefulWidget {
  /// 自己是否为决斗者；观战者只显示等待状态。
  final bool isDuelist;

  /// 正在编辑的换备构成；null 表示数据尚未初始化完成。
  final List<CardInfo>? sidingMain;
  final List<CardInfo>? sidingExtra;
  final List<CardInfo>? sidingSide;

  /// 换备数据初始化是否失败（持久标志，区别于加载中）。
  final bool sidingInitFailed;

  /// 初始化失败后的重试回调（null 表示当前不可重试）。
  final VoidCallback? onRetryInit;

  /// 基准数量（换备前后各分区数量必须保持一致）。
  final int baselineMainCount;
  final int baselineExtraCount;
  final int baselineSideCount;

  /// 移动卡片回调：[SidingZone.from] → [SidingZone.to]，下标为 from 分区内位置。
  final void Function(SidingZone from, SidingZone to, int index) onMoveCard;

  /// 恢复为基准构成。
  final VoidCallback onReset;

  /// 确认换备（提交卡组并 ready）；返回的 Future 在提交完成后结束，
  /// 面板据此在提交期间禁用按钮，防止禁限校验往返时双击重复提交。
  final Future<void> Function() onConfirm;

  const SideDeckingPanel({
    super.key,
    required this.isDuelist,
    required this.sidingMain,
    required this.sidingExtra,
    required this.sidingSide,
    this.sidingInitFailed = false,
    this.onRetryInit,
    required this.baselineMainCount,
    required this.baselineExtraCount,
    required this.baselineSideCount,
    required this.onMoveCard,
    required this.onReset,
    required this.onConfirm,
  });

  @override
  State<SideDeckingPanel> createState() => _SideDeckingPanelState();
}

class _SideDeckingPanelState extends State<SideDeckingPanel> {
  /// 确认提交中（含禁限校验的网络往返）：期间禁用按钮防重复提交。
  bool _submitting = false;

  bool get _countsValid =>
      widget.sidingMain != null &&
      widget.sidingExtra != null &&
      widget.sidingSide != null &&
      widget.sidingMain!.length == widget.baselineMainCount &&
      widget.sidingExtra!.length == widget.baselineExtraCount &&
      widget.sidingSide!.length == widget.baselineSideCount;

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onConfirm();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: HudTheme.panel(radius: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz, size: 16, color: HudTheme.gold),
              const SizedBox(width: 6),
              const Text('换备', style: HudTheme.title),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '主/额外卡组与副卡组互换',
                  style: HudTheme.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!widget.isDuelist)
            _statusRow(Icons.hourglass_bottom, '决斗者换备中…')
          else if (widget.sidingMain == null ||
              widget.sidingExtra == null ||
              widget.sidingSide == null)
            // 初始化失败给重试入口（否则面板会永远停在加载态，
            // 而换备期间 ControlBar 无操作按钮，没有其他出口）。
            widget.sidingInitFailed
                ? Row(
                    children: [
                      Expanded(
                        child: _statusRow(
                          Icons.error_outline,
                          '换备数据初始化失败',
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onRetryInit,
                        child: const Text(
                          '重试',
                          style: TextStyle(color: HudTheme.cyan),
                        ),
                      ),
                    ],
                  )
                : _statusRow(Icons.settings, '正在准备换备数据…')
          else ...[
            _cardSection(
              icon: Icons.style,
              title: '主卡组',
              cards: widget.sidingMain!,
              baselineCount: widget.baselineMainCount,
              zone: SidingZone.main,
              hint: '点击移入副卡组',
            ),
            const SizedBox(height: 8),
            _cardSection(
              icon: Icons.auto_awesome,
              title: '额外卡组',
              cards: widget.sidingExtra!,
              baselineCount: widget.baselineExtraCount,
              zone: SidingZone.extra,
              hint: '点击移入副卡组',
            ),
            const SizedBox(height: 8),
            _sideSection(),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onReset,
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('重置'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HudTheme.textPrimary,
                    side: const BorderSide(color: HudTheme.panelBorder),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('side-decking-confirm'),
                    onPressed: _countsValid && !_submitting ? _confirm : null,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle, size: 16),
                    label: Text(_submitting ? '提交中…' : '确认换备'),
                    style: FilledButton.styleFrom(
                      backgroundColor: HudTheme.cyanDim,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: HudTheme.panelBg,
                      disabledForegroundColor: HudTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 观战/加载状态行。
  Widget _statusRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: HudTheme.textSecondary),
          const SizedBox(width: 6),
          Text(text, style: HudTheme.body.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  /// 主/额外分区：卡片为可点击 chip，点击移入副卡组。
  Widget _cardSection({
    required IconData icon,
    required String title,
    required List<CardInfo> cards,
    required int baselineCount,
    required SidingZone zone,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(icon, title, cards.length, baselineCount, hint),
        const SizedBox(height: 4),
        if (cards.isEmpty)
          Text('（空）', style: HudTheme.caption)
        else
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < cards.length; i++)
                _cardChip(
                  cards[i],
                  onTap: () => widget.onMoveCard(zone, SidingZone.side, i),
                ),
            ],
          ),
      ],
    );
  }

  /// 副卡组分区：每张卡提供「→主」「→额」两个去向按钮。
  Widget _sideSection() {
    final cards = widget.sidingSide!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          Icons.inventory_2,
          '副卡组',
          cards.length,
          widget.baselineSideCount,
          '选择去向',
        ),
        const SizedBox(height: 4),
        if (cards.isEmpty)
          Text('（空）', style: HudTheme.caption)
        else
          Column(
            children: [
              for (var i = 0; i < cards.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          cards[i].name.isNotEmpty
                              ? cards[i].name
                              : '${cards[i].code}',
                          style: HudTheme.body.copyWith(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 「→主」「→额」按卡类型互斥：额外卡组类型
                      // （融合/同调/超量/连接）只能回额外卡组，其余卡
                      // 只能回主卡组；放错会被服务端按「卡组无效」拒绝。
                      if (!_isExtraDeckCard(cards[i]))
                        _moveButton(
                          '→主',
                          () => widget.onMoveCard(
                            SidingZone.side,
                            SidingZone.main,
                            i,
                          ),
                        ),
                      if (_isExtraDeckCard(cards[i])) ...[
                        const SizedBox(width: 4),
                        _moveButton(
                          '→额',
                          () => widget.onMoveCard(
                            SidingZone.side,
                            SidingZone.extra,
                            i,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// 分区标题：图标 + 名称 + 实时数量「X/基准Y」（与基准一致时绿色）。
  Widget _sectionHeader(
    IconData icon,
    String title,
    int count,
    int baselineCount,
    String hint,
  ) {
    final matched = count == baselineCount;
    final color = matched ? HudTheme.heal : HudTheme.gold;
    return Row(
      children: [
        Icon(icon, size: 14, color: HudTheme.textSecondary),
        const SizedBox(width: 6),
        Text(
          '$title $count/基准$baselineCount',
          style: HudTheme.body.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            hint,
            style: HudTheme.caption,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// 是否额外卡组类型（融合/同调/超量/连接）：决定副卡区「→额」去向。
  static bool _isExtraDeckCard(CardInfo card) =>
      card.isFusion || card.isSynchro || card.isXyz || card.isLink;

  /// 可点击卡片 chip（主/额外分区）。
  Widget _cardChip(CardInfo card, {required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        splashColor: HudTheme.cyan.withValues(alpha: 0.15),
        highlightColor: HudTheme.cyan.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1626),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: HudTheme.panelBorder),
          ),
          child: Text(
            card.name.isNotEmpty ? card.name : '${card.code}',
            style: HudTheme.body.copyWith(fontSize: 12),
          ),
        ),
      ),
    );
  }

  /// 副卡组卡片去向小按钮。
  Widget _moveButton(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        splashColor: HudTheme.cyan.withValues(alpha: 0.15),
        highlightColor: HudTheme.cyan.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: HudTheme.cyanDim),
          ),
          child: Text(
            label,
            style: HudTheme.caption.copyWith(color: HudTheme.cyan),
          ),
        ),
      ),
    );
  }
}
