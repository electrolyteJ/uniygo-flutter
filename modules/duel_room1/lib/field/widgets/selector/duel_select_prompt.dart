import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:biz/duel/field/duel_field_derived.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:duel_room1/field/widgets/selector/announce_card_dialog.dart';
import 'package:duel_room1/field/widgets/selector/announce_choice_dialog.dart';
import 'package:duel_room1/field/widgets/selector/card_selector.dart';
import 'package:duel_room1/field/widgets/selector/counter_select_dialog.dart';
import 'package:duel_room1/field/widgets/selector/position_selector.dart';
import 'package:duel_room1/field/widgets/selector/yes_no_dialog.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';

/// 选择提示弹层：订阅 select 子状态、决定呈现方式（放置提示横幅 /
/// 就地选择操作栏 / 模态弹窗，三者互斥）并组装具体选择组件。
///
/// 选择响应（respondXxx）的分发全部收口在这里；所有 respond* 调用都在
/// build 时捕获当前窗口的 generation，过期窗口（generation 不匹配）的
/// 响应由 notifier 丢弃。检视卡片（onInspectCard）由页面注入（含音效与
/// 详情抽屉联动）。
///
/// 呈现与组装合并在本组件内（原 SelectPromptLayer 纯壳层已并入：
/// 它只是把这里读到的 state 再转述一遍，没有独立价值）。
/// 对照 duel_room2 的 field/widgets/overlay/duel_select_overlay.dart。
/// 页面在 Stack 中直接插入本组件：none 模式渲染空盒子，其余模式
/// Positioned.fill 铺满（modal 阻断全屏点击，place/inline 仅局部响应）。
class DuelSelectPrompt extends ConsumerWidget {
  const DuelSelectPrompt({super.key, required this.onInspectCard});

  /// 检视卡片回调（页面注入：播音效 + 打开详情抽屉）。
  final void Function(int code) onInspectCard;

  static final _panelDecoration = BoxDecoration(
    color: const Color(0xE6111722),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 20,
        offset: Offset(0, 10),
      ),
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(selectPromptModeProvider);
    // 同模式内的窗口推进（选项/提示语变化）也要驱动重建。
    ref.watch(
      selectWindowProvider.select(
        (s) => (
          s.currentSelect,
          s.inlineSelectHint,
          s.inlineSelectCanConfirm,
          s.placeTargetFieldKeys.length,
        ),
      ),
    );
    if (mode == SelectPromptMode.none) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(child: _buildLayer(context, ref, mode));
  }

  Widget _buildLayer(
    BuildContext context,
    WidgetRef ref,
    SelectPromptMode mode,
  ) {
    final state = ref.read(selectWindowProvider);
    if (mode == SelectPromptMode.modal && state.currentSelect == null) {
      return const IgnorePointer(child: SizedBox.expand());
    }
    final selectN = ref.read(selectWindowProvider.notifier);
    switch (mode) {
      case SelectPromptMode.none:
        return const SizedBox.shrink();
      case SelectPromptMode.place:
        return _buildPlaceHint(context, state.placeTargetFieldKeys.length);
      case SelectPromptMode.inline:
        return _buildInlineBar(context, state, selectN);
      case SelectPromptMode.modal:
        final select = state.currentSelect!;
        // 模态弹窗：遮罩全屏并居中展示选择组件。
        return Container(
          key: const ValueKey('select-modal-barrier'),
          color: Colors.black.withValues(alpha: 0.65),
          child: _buildSelectModal(
            selectN,
            select,
            state.announceCardDeclarableCodes,
          ),
        );
    }
  }

  /// 放置选择（MSG_SELECT_PLACE）的提示横幅；可放置槽位的高亮与点击
  /// 已下沉到场地槽位组件本身，此处仅保留文案提示，不拦截点击。
  Widget _buildPlaceHint(BuildContext context, int placeTargetCount) {
    final spec = DuelRoomLayout.of(context);
    return Stack(
      children: [
        Positioned(
          top: spec.safeRect.top + spec.topHudHeight + spec.panelGap,
          left: spec.safeRect.left + spec.panelGap,
          right: spec.viewport.width - spec.safeRect.right + spec.panelGap,
          child: IgnorePointer(
            child: Center(
              child: Container(
                key: const ValueKey('select-place-hint'),
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: _panelDecoration,
                child: Text(
                  '请选择放置区域${placeTargetCount == 1 ? '' : '（可选 $placeTargetCount 处）'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 就地选择的操作栏：提示文案 + 取消/确认/完成，置于手牌栏上方。
  Widget _buildInlineBar(
    BuildContext context,
    SelectWindowState state,
    SelectWindowNotifier selectN,
  ) {
    final spec = DuelRoomLayout.of(context);
    final select = state.currentSelect;
    // 多选（非单张、非连锁、非解除选择）才需要本地确认按钮。
    final showConfirm =
        select != null &&
        select.type != SelectType.chain &&
        select.type != SelectType.unselect &&
        !(select.min == 1 && select.max == 1);
    final cancelLabel = select?.cancelable == true
        ? (select!.type == SelectType.chain ? '不连锁' : '取消')
        : null;
    final showFinish =
        select?.type == SelectType.unselect && select!.finishable;
    return Stack(
      children: [
        Positioned(
          left: spec.safeRect.left + spec.panelGap,
          right: spec.viewport.width - spec.safeRect.right + spec.panelGap,
          bottom: spec.safePadding.bottom + spec.handBarHeight + spec.panelGap,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: spec.dialogMaxSize.width),
              child: Container(
                key: const ValueKey('select-inline-bar'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: _panelDecoration,
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 420,
                      ),
                      child: Text(
                        state.inlineSelectHint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (cancelLabel != null) ...[
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: selectN.cancelInlineSelect,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: Text(cancelLabel),
                      ),
                    ],
                    if (showFinish) ...[
                      const SizedBox(width: 4),
                      _actionButton(
                        label: '完成',
                        enabled: state.inlineSelectCanConfirm,
                        onPressed: selectN.finishInlineUnselect,
                      ),
                    ] else if (showConfirm) ...[
                      const SizedBox(width: 4),
                      _actionButton(
                        label: '确认',
                        enabled: state.inlineSelectCanConfirm,
                        onPressed: selectN.confirmInlineSelect,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required bool enabled,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00F0FF),
        foregroundColor: Colors.black,
        disabledBackgroundColor: Colors.grey.shade800,
        disabledForegroundColor: Colors.grey.shade500,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: Text(label),
    );
  }

  /// 模态选择弹窗：选项落在不可直接点击的区域的回退，
  /// 以及排序/计数器/效果选项等复杂交互。
  Widget _buildSelectModal(
    SelectWindowNotifier selectN,
    SelectState select,
    Set<int>? declarableCodes,
  ) {
    final generation = select.generation;
    switch (select.type) {
      case SelectType.card:
      case SelectType.tribute:
        return CardSelector(
          select: select,
          onSelect: (sequences) =>
              selectN.respondSelectCard(sequences, generation: generation),
          // 取消必须走引擎语义：min>=1 的可取消窗口回 selectSingle(-1)，
          // 空 selectMulti 会被引擎当成「选 0 张」回 MSG_RETRY，而
          // handleRetry 不重开此类窗口，对局将卡死。
          onCancel: selectN.cancelInlineSelect,
          onInspectCard: onInspectCard,
        );
      case SelectType.unselect:
        return CardSelector(
          select: select,
          onSelect: (sequences) => selectN.respondSelectUnselectCard(
            sequences.isEmpty ? null : sequences.first,
            generation: generation,
          ),
          onCancel: () =>
              selectN.respondSelectUnselectCard(null, generation: generation),
          onInspectCard: onInspectCard,
        );
      case SelectType.chain:
        return CardSelector(
          select: select,
          onSelect: (sequences) => selectN.respondSelectChain(
            sequences.isNotEmpty ? sequences.first : -1,
            generation: generation,
          ),
          onCancel: () =>
              selectN.respondSelectChain(-1, generation: generation),
          onInspectCard: onInspectCard,
        );
      case SelectType.position:
        return PositionSelector(
          select: select,
          onSelect: (position) =>
              selectN.respondSelectPosition(position, generation: generation),
        );
      case SelectType.effectYn:
        return YesNoDialog(
          message: '是否发动效果？',
          cardCode: select.options.isNotEmpty
              ? select.options.first.code
              : null,
          onInspectCard: onInspectCard,
          onYes: () =>
              selectN.respondSelectEffectYn(true, generation: generation),
          onNo: () =>
              selectN.respondSelectEffectYn(false, generation: generation),
        );
      case SelectType.yesNo:
        return YesNoDialog(
          message: '是否执行？',
          cardCode: select.options.isNotEmpty
              ? select.options.first.code
              : null,
          onInspectCard: onInspectCard,
          onYes: () => selectN.respondSelectYesNo(true, generation: generation),
          onNo: () => selectN.respondSelectYesNo(false, generation: generation),
        );
      case SelectType.option:
        return CardSelector(
          select: select,
          onSelect: (sequences) => selectN.respondSelectOption(
            sequences.isNotEmpty ? sequences.first : 0,
            generation: generation,
          ),
          onCancel: () =>
              selectN.respondSelectOption(0, generation: generation),
          onInspectCard: onInspectCard,
        );
      case SelectType.announceCard:
        return AnnounceCardDialog(
          generation: generation,
          // 受限宣言（抹杀之指名者等）：把引擎下发的可宣言卡集合
          // 传给弹窗直接罗列候选；null 时退回自由宣言搜索。
          declarableCodes: declarableCodes,
          onLoadDeclarable: selectN.loadDeclarableCards,
          onSearch: selectN.searchAnnounceCards,
          onSelect: (code) =>
              selectN.respondAnnounceCard(code, generation: generation),
          onInspectCard: onInspectCard,
        );
      case SelectType.announceNumber:
        return AnnounceChoiceDialog(
          title: '宣言数值',
          options: select.options,
          onSelect: (index) =>
              selectN.respondAnnounceNumber(index, generation: generation),
        );
      case SelectType.announceAttrib:
        return AnnounceChoiceDialog(
          title: '宣言属性',
          options: select.options,
          onSelect: (index) =>
              selectN.respondAnnounceAttrib(index, generation: generation),
        );
      case SelectType.announceRace:
        return AnnounceChoiceDialog(
          title: '宣言种族',
          options: select.options,
          onSelect: (index) =>
              selectN.respondAnnounceRace(index, generation: generation),
        );
      case SelectType.sum:
        return CardSelector(
          select: select,
          onSelect: (sequences) =>
              selectN.respondSelectSum(sequences, generation: generation),
          onCancel: () => selectN.respondSelectSum([], generation: generation),
          onInspectCard: onInspectCard,
          // SUM 的合法性是合计数值（引擎 sum_check），不是张数下限；
          // 不合法的回包会吃 MSG_RETRY 且窗口不重开，对局卡死。
          selectionValidator: selectN.isSumSelectionValid,
        );
      case SelectType.counter:
        // 计数器窗口的应答是「每卡移除数量」列表，CardSelector 的
        // 下标多选语义无法满足（会被 respondSelectCounter 拒绝且窗口
        // 不可取消），必须用专用的逐卡步进弹窗。
        return CounterSelectDialog(
          select: select,
          onSelect: (counts) =>
              selectN.respondSelectCounter(counts, generation: generation),
          onInspectCard: onInspectCard,
        );
      case SelectType.sort:
        return CardSelector(
          select: select,
          onSelect: (sequences) =>
              selectN.respondSortCard(sequences, generation: generation),
          onCancel: () => selectN.respondSortCard([], generation: generation),
          onInspectCard: onInspectCard,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
