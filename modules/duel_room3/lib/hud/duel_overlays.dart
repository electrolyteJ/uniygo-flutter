import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'announce_card_dialog.dart';
import 'counter_allocator_dialog.dart';
import 'hud_theme.dart';
import 'select_dispatch.dart';

/// 选择窗口 HUD（MDPro3 风格）：顶部提示横幅 + 就地选择操作栏 +
/// 模态对话框（是否/选项/表示形式/卡网格/指示物/排序/宣言卡名）。
///
/// 分发逻辑收敛在 select_dispatch.dart 的纯函数（可单测）；
/// 响应回包的 generation 在 build 时捕获并逐处传入，
/// 迟到响应由 biz 的 _acceptGeneration 门卫丢弃。
class DuelSelectOverlay extends ConsumerWidget {
  const DuelSelectOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final select = ref.watch(selectWindowProvider);
    final current = select.currentSelect;
    if (current == null) return const SizedBox.shrink();

    final board = ref.watch(duelFieldProvider);
    // modal/inline 分流由 biz 的纯函数判定：选项落在墓地/卡组/除外/
    // 对方手牌等不可点击区域时必须出 modal 卡网格，否则软锁。
    final mode = resolveSelectPromptMode(select, board);
    final selectN = ref.read(selectWindowProvider.notifier);

    return Stack(
      children: [
        // 顶部提示横幅
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: HudTheme.glowPanel(radius: 20),
              child: Text(
                select.inlineSelectHint,
                style: HudTheme.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        // 模态对话框（含遮罩与返回键拦截）
        if (mode == SelectPromptMode.modal)
          Positioned.fill(
            child: _ModalScaffold(select: current, selectN: selectN),
          ),
        // 就地选择操作栏：取消（chain=「不连锁」）+ 确认/完成
        if (mode == SelectPromptMode.inline)
          Positioned(
            bottom: 130,
            left: 0,
            right: 0,
            child: Center(child: _InlineActionBar(select: select)),
          ),
      ],
    );
  }
}

/// 就地选择操作栏（对照 room2 select_prompt_layer 的 inline bar）。
class _InlineActionBar extends ConsumerWidget {
  const _InlineActionBar({required this.select});

  final SelectWindowState select;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = select.currentSelect!;
    final selectN = ref.read(selectWindowProvider.notifier);
    final cancelLabel = inlineCancelLabel(current);
    final action = inlineSelectAction(current);
    if (cancelLabel == null && action == InlineSelectAction.none) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: HudTheme.glowPanel(radius: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cancelLabel != null) ...[
            TextButton(
              onPressed: selectN.cancelInlineSelect,
              style: TextButton.styleFrom(
                foregroundColor: HudTheme.danger,
                minimumSize: const Size(0, 34),
              ),
              child: Text(cancelLabel),
            ),
            const SizedBox(width: 6),
          ],
          if (action == InlineSelectAction.confirm)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: HudTheme.cyanDim,
                disabledBackgroundColor: Colors.grey.shade800,
              ),
              icon: const Icon(Icons.check, size: 18),
              label: Text('确认 (${select.inlineSelectedCount})'),
              // confirmInlineSelect 内部按类型分发（tribute/sum/card）并
              // 先做 SUM 引擎校验，非法组合不发包（避免 MSG_RETRY）。
              onPressed: select.inlineSelectCanConfirm
                  ? selectN.confirmInlineSelect
                  : null,
            ),
          if (action == InlineSelectAction.finish)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: HudTheme.cyanDim,
                disabledBackgroundColor: Colors.grey.shade800,
              ),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('完成'),
              // unselect 的「完成」必须回 -1（finishInlineUnselect），
              // 不能走 respondInlineMulti（它只特判 tribute/sum）。
              onPressed: select.inlineSelectCanConfirm
                  ? selectN.finishInlineUnselect
                  : null,
            ),
        ],
      ),
    );
  }
}

/// modal 弹窗脚手架：65% 黑遮罩阻断场地点击穿透；
/// PopScope 拦截返回键——可取消窗口的返回键 = 取消本次选择，
/// 不可取消时直接拦截（否则触发页面级「退出房间」）。
class _ModalScaffold extends StatelessWidget {
  const _ModalScaffold({required this.select, required this.selectN});

  final SelectState select;
  final SelectWindowNotifier selectN;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (select.cancelable) selectN.cancelInlineSelect();
      },
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _ModalForSelect(select: select),
          ),
        ),
      ),
    );
  }
}

/// 按窗口类型分发 modal 弹窗；所有 respond* 调用都携带 build 时捕获的
/// generation（biz _acceptGeneration 依赖它丢弃迟到响应）。
class _ModalForSelect extends ConsumerWidget {
  const _ModalForSelect({required this.select});

  final SelectState select;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(selectWindowProvider.notifier);
    final generation = select.generation;
    switch (selectModalKind(select.type)) {
      case SelectModalKind.yesNo:
        final isEffect = select.type == SelectType.effectYn;
        // 是/否按钮恒显：cancelable 是「可取消窗口」语义（控制返回键），
        // 不是「可拒绝」；否则玩家无法拒绝发动效果（对局级错误）。
        return _TwoChoiceDialog(
          title: select.hint ?? '是否发动效果？',
          onYes: () => isEffect
              ? notifier.respondSelectEffectYn(true, generation: generation)
              : notifier.respondSelectYesNo(true, generation: generation),
          onNo: () => isEffect
              ? notifier.respondSelectEffectYn(false, generation: generation)
              : notifier.respondSelectYesNo(false, generation: generation),
        );
      case SelectModalKind.option:
        return _OptionDialog(select: select);
      case SelectModalKind.position:
        return _PositionDialog(select: select);
      case SelectModalKind.announceCard:
        final declarable = ref.watch(
          selectWindowProvider.select((s) => s.announceCardDeclarableCodes),
        );
        return AnnounceCardDialog(
          hint: select.hint,
          declarableCodes: declarable,
          onLoadDeclarable: notifier.loadDeclarableCards,
          onSearch: notifier.searchAnnounceCards,
          onSelect: (code) =>
              notifier.respondAnnounceCard(code, generation: generation),
        );
      case SelectModalKind.cardGrid:
        return _cardGridFor(select, notifier, generation);
      case SelectModalKind.counter:
        final boardN = ref.read(duelFieldProvider.notifier);
        return CounterAllocatorDialog(
          select: select,
          cardNameBuilder: (code) =>
              boardN.getCardInfo(code)?.name ?? 'Card #$code',
          onSubmit: (counts) =>
              notifier.respondSelectCounter(counts, generation: generation),
          onCancel: select.cancelable
              ? () => notifier.respondSelectCounter(
                  const [],
                  generation: generation,
                )
              : null,
        );
      case SelectModalKind.sort:
        return CardGridSelectDialog(
          select: select,
          title: select.hint ?? '按顺序点击卡片进行排序',
          ordered: true,
          submitLabel: '确认排序',
          onSubmit: (indices) =>
              notifier.respondSortCard(indices, generation: generation),
        );
      case SelectModalKind.none:
        return const SizedBox.shrink();
    }
  }

  /// card/tribute/chain/unselect/sum 的 modal 卡网格回包分发。
  Widget _cardGridFor(
    SelectState select,
    SelectWindowNotifier notifier,
    int generation,
  ) {
    final title = select.hint ?? '请选择卡片';
    switch (select.type) {
      case SelectType.chain:
        return CardGridSelectDialog(
          select: select,
          title: title,
          onImmediateTap: (i) =>
              notifier.respondSelectChain(i, generation: generation),
          onCancel: select.cancelable
              ? () => notifier.respondSelectChain(-1, generation: generation)
              : null,
          cancelLabel: '不连锁',
        );
      case SelectType.unselect:
        // 点卡即回 toggle；「完成」回 -1 确认当前勾选。
        return CardGridSelectDialog(
          select: select,
          title: title,
          onImmediateTap: (i) =>
              notifier.respondSelectUnselectCard(i, generation: generation),
          submitLabel: '完成',
          onSubmit: (_) =>
              notifier.respondSelectUnselectCard(null, generation: generation),
          onCancel: select.cancelable
              ? () => notifier.respondSelectUnselectCard(
                  null,
                  generation: generation,
                )
              : null,
        );
      case SelectType.sum:
        return CardGridSelectDialog(
          select: select,
          title: title,
          canSubmit: notifier.isSumSelectionValid,
          onSubmit: (indices) =>
              notifier.respondSelectSum(indices, generation: generation),
          onCancel: select.cancelable
              ? () => notifier.respondSelectSum(const [], generation: generation)
              : null,
        );
      default:
        // card / tribute：单选点卡即答，多选确认提交。
        final single = select.min == 1 && select.max == 1;
        return CardGridSelectDialog(
          select: select,
          title: title,
          onImmediateTap: single
              ? (i) => notifier.respondSelectCard([i], generation: generation)
              : null,
          onSubmit: (indices) =>
              notifier.respondSelectCard(indices, generation: generation),
          onCancel: select.cancelable
              ? () =>
                  notifier.respondSelectCard(const [], generation: generation)
              : null,
        );
    }
  }
}

/// 是否/效果确认对话框：是与否按钮恒显（对照 room2 yes_no_dialog）。
class _TwoChoiceDialog extends StatelessWidget {
  const _TwoChoiceDialog({
    required this.title,
    required this.onYes,
    required this.onNo,
  });

  final String title;
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: HudTheme.glowPanel(radius: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: HudTheme.title, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: HudTheme.cyanDim,
                ),
                onPressed: onYes,
                child: const Text('是'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: HudTheme.textPrimary,
                  side: const BorderSide(color: HudTheme.panelBorder),
                ),
                onPressed: onNo,
                child: const Text('否'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 选项/宣言数值/宣言属性种族的列表弹窗。
class _OptionDialog extends ConsumerWidget {
  const _OptionDialog({required this.select});

  final SelectState select;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(selectWindowProvider.notifier);
    final generation = select.generation;
    void respond(int index) {
      switch (select.type) {
        case SelectType.announceNumber:
          notifier.respondAnnounceNumber(index, generation: generation);
        case SelectType.announceAttrib:
          notifier.respondAnnounceAttrib(index, generation: generation);
        case SelectType.announceRace:
          notifier.respondAnnounceRace(index, generation: generation);
        default:
          notifier.respondSelectOption(index, generation: generation);
      }
    }

    return Container(
      width: 360,
      padding: const EdgeInsets.all(16),
      decoration: HudTheme.glowPanel(radius: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(select.hint ?? '请选择一项', style: HudTheme.title),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var i = 0; i < select.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF123049),
                        foregroundColor: HudTheme.textPrimary,
                      ),
                      onPressed: () => respond(i),
                      child: Text(select.options[i].label ?? '选项 ${i + 1}'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionDialog extends ConsumerWidget {
  const _PositionDialog({required this.select});

  final SelectState select;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(selectWindowProvider.notifier);
    final generation = select.generation;
    final entries = <(String, IconData, int)>[
      for (final option in select.options)
        if (option.position != null)
          (
            _positionLabel(option.position!),
            _positionIcon(option.position!),
            option.position!,
          ),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: HudTheme.glowPanel(radius: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('选择表示形式', style: HudTheme.title),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, icon, pos) in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: InkWell(
                    onTap: () => notifier.respondSelectPosition(
                      pos,
                      generation: generation,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: HudTheme.panel(radius: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: HudTheme.cyan, size: 26),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: HudTheme.caption.copyWith(
                              color: HudTheme.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _positionLabel(int position) => switch (position) {
    0x1 => '表侧攻击',
    0x4 => '表侧守备',
    0x8 => '里侧守备',
    _ => '表示 $position',
  };

  static IconData _positionIcon(int position) => switch (position) {
    0x1 => Icons.north,
    0x4 => Icons.swap_horiz,
    0x8 => Icons.flip_to_back,
    _ => Icons.help_outline,
  };
}

/// 卡网格选择对话框：modal 回退场景（选项在墓地/卡组/除外/对方手牌等
/// 不可就地点击的区域）的卡选择 UI。
///
/// 交互模式：
/// - [onImmediateTap] 非 null：点卡即回包（chain / 单选 card / unselect
///   逐张 toggle）；unselect 的「完成」经 [onSubmit] 回空列表。
/// - 否则多选：点卡切换勾选，[submitLabel] 按钮提交（[canSubmit] 可注入
///   SUM 引擎校验）。
/// - [ordered]（sort）：按点选顺序收集，选满全部选项才能提交。
class CardGridSelectDialog extends StatefulWidget {
  const CardGridSelectDialog({
    super.key,
    required this.select,
    required this.title,
    this.onImmediateTap,
    this.onSubmit,
    this.onCancel,
    this.canSubmit,
    this.submitLabel = '确认',
    this.cancelLabel = '取消',
    this.ordered = false,
  });

  final SelectState select;
  final String title;

  /// 点卡即回包模式（chain / 单选 / unselect toggle）。
  final void Function(int index)? onImmediateTap;

  /// 多选/排序/完成提交：回传选项下标（ordered 时按点选顺序）。
  final void Function(List<int> indices)? onSubmit;

  /// 取消回调；null 时不显示取消按钮。
  final VoidCallback? onCancel;

  /// 多选提交可用性判定（如 SUM 合计校验）；null 时按数量 >= min 判定。
  final bool Function(Set<int> selected)? canSubmit;

  final String submitLabel;
  final String cancelLabel;

  /// 排序模式：按点选顺序收集，选满全部选项才可提交。
  final bool ordered;

  @override
  State<CardGridSelectDialog> createState() => _CardGridSelectDialogState();
}

class _CardGridSelectDialogState extends State<CardGridSelectDialog> {
  final List<int> _selected = []; // ordered 时保序；否则当集合用

  @override
  void initState() {
    super.initState();
    _resetFromWidget();
  }

  @override
  void didUpdateWidget(covariant CardGridSelectDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.select, widget.select)) {
      _resetFromWidget();
    }
  }

  /// unselect 窗口重开时同步服务端已勾选状态（initialSelectedIndices）。
  void _resetFromWidget() {
    _selected
      ..clear()
      ..addAll(widget.select.initialSelectedIndices);
  }

  bool get _isImmediate => widget.onImmediateTap != null;

  bool get _canSubmit {
    if (widget.ordered) {
      return _selected.length == widget.select.options.length;
    }
    final custom = widget.canSubmit;
    if (custom != null) return custom(_selected.toSet());
    // unselect「完成」由服务端 finishable 控制；勾选数下限仍按 min。
    return _selected.length >= widget.select.min;
  }

  /// 是否显示提交按钮：unselect（immediateSingleToggle）仅在可完成时；
  /// immediate 单选/chain 无提交按钮；其余多选恒显示。
  bool get _showSubmit {
    if (widget.onSubmit == null) return false;
    if (widget.select.immediateSingleToggle) return widget.select.finishable;
    return !_isImmediate || widget.ordered;
  }

  void _onTapCard(int index) {
    final immediate = widget.onImmediateTap;
    if (immediate != null) {
      immediate(index);
      return;
    }
    setState(() {
      if (widget.ordered) {
        // 排序：重复点选 = 移除（再点别的追加到末尾调整顺序）。
        if (_selected.contains(index)) {
          _selected.remove(index);
        } else {
          _selected.add(index);
        }
        return;
      }
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else if (_selected.length < widget.select.max ||
          widget.select.type == SelectType.sum && widget.select.sumExact) {
        _selected.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final select = widget.select;
    return Container(
      width: 520,
      constraints: const BoxConstraints(maxHeight: 460),
      padding: const EdgeInsets.all(16),
      decoration: HudTheme.glowPanel(radius: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: HudTheme.title, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 82,
                childAspectRatio: 59 / 86,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: select.options.length,
              itemBuilder: (context, index) => _buildCardItem(index),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              if (widget.onCancel != null) ...[
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(
                    widget.cancelLabel,
                    style: const TextStyle(color: HudTheme.danger),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (_showSubmit)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: HudTheme.cyanDim,
                    disabledBackgroundColor: Colors.grey.shade800,
                  ),
                  onPressed: _canSubmit
                      ? () => widget.onSubmit!(List<int>.of(_selected))
                      : null,
                  child: Text(
                    widget.ordered
                        ? '${widget.submitLabel} (${_selected.length}/${select.options.length})'
                        : widget.submitLabel,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(int index) {
    final option = widget.select.options[index];
    final selected = _selected.contains(index);
    final order = widget.ordered && selected ? _selected.indexOf(index) + 1 : 0;
    return GestureDetector(
      onTap: () => _onTapCard(index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CardImage(code: option.code, width: 82, height: 120),
            if (!selected && !_isImmediate)
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
            if (selected)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: HudTheme.cyan, width: 3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            if (order > 0)
              Positioned(
                top: 2,
                left: 2,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: HudTheme.cyan,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$order',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
