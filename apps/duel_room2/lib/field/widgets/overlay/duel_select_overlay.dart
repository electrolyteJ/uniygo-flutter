import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'announce_card_dialog.dart';
import 'announce_choice_dialog.dart';
import 'card_selector.dart';
import 'counter_allocator_dialog.dart';
import 'position_selector.dart';
import 'select_prompt_layer.dart';
import 'yes_no_dialog.dart';

/// 选择提示层：把 select 子状态组装成 [SelectPromptLayer] 的纯 UI props。
///
/// 选择响应（respondXxx）的分发全部收口在这里；所有 respond* 调用都在
/// build 时捕获当前窗口的 generation，过期窗口（generation 不匹配）的
/// 响应由 notifier 丢弃。检视卡片（onInspectCard）由页面注入。
class DuelSelectOverlay extends ConsumerWidget {
  const DuelSelectOverlay({
    super.key,
    required this.mode,
    required this.onInspectCard,
  });

  final SelectPromptMode mode;
  final void Function(int code) onInspectCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(selectWindowProvider);
    final select = state.currentSelect;
    final selectN = ref.read(selectWindowProvider.notifier);
    final boardN = ref.read(duelFieldProvider.notifier);
    final myController =
        ref.watch(duelFieldProvider.select((b) => b.myController));

    switch (mode) {
      case SelectPromptMode.none:
        return const SizedBox.shrink();
      case SelectPromptMode.place:
        return SelectPromptLayer(
          mode: mode,
          placeTargetCount: state.placeTargetFieldKeys.length,
        );
      case SelectPromptMode.inline:
        // 多选（非单张、非连锁、非解除选择）才需要本地确认按钮。
        final showConfirm =
            select != null &&
            select.type != SelectType.chain &&
            select.type != SelectType.unselect &&
            !(select.min == 1 && select.max == 1);
        return SelectPromptLayer(
          mode: mode,
          inlineHint: state.inlineSelectHint,
          inlineCancelLabel: select?.cancelable == true
              ? (select!.type == SelectType.chain ? '不连锁' : '取消')
              : null,
          inlineShowFinish:
              select?.type == SelectType.unselect && select!.finishable,
          inlineShowConfirm: showConfirm,
          inlineCanConfirm: state.inlineSelectCanConfirm,
          onInlineCancel: selectN.cancelInlineSelect,
          onInlineFinish: selectN.finishInlineUnselect,
          onInlineConfirm: selectN.confirmInlineSelect,
        );
      case SelectPromptMode.modal:
        return SelectPromptLayer(
          mode: mode,
          modalChild: select == null
              ? null
              : _buildSelectModal(
                  selectN,
                  boardN,
                  select,
                  state.announceCardDeclarableCodes,
                  myController,
                ),
          modalCancelable: select?.cancelable ?? false,
          onModalCancel: selectN.cancelInlineSelect,
        );
    }
  }

  Widget _buildSelectModal(
    SelectWindowNotifier selectN,
    DuelFieldNotifier boardN,
    SelectState select,
    Set<int>? declarableCodes,
    int myController,
  ) {
    final generation = select.generation;
    switch (select.type) {
      case SelectType.card:
      case SelectType.tribute:
        return CardSelector(
          select: select,
          onSelect: (sequences) =>
              selectN.respondSelectCard(sequences, generation: generation),
          onCancel: () => selectN.respondSelectCard([], generation: generation),
          onInspectCard: onInspectCard,
          myController: myController,
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
          myController: myController,
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
          myController: myController,
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
          myController: myController,
        );
      case SelectType.announceCard:
        return AnnounceCardDialog(
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
          isSumSelectionValid: selectN.isSumSelectionValid,
          onSelect: (sequences) =>
              selectN.respondSelectSum(sequences, generation: generation),
          onCancel: () => selectN.respondSelectSum([], generation: generation),
          onInspectCard: onInspectCard,
          myController: myController,
        );
      case SelectType.counter:
        return CounterAllocatorDialog(
          select: select,
          cardNameBuilder: (code) =>
              boardN.getCardInfo(code)?.name ?? 'Card #$code',
          onInspectCard: onInspectCard,
          onSubmit: (counts) =>
              selectN.respondSelectCounter(counts, generation: generation),
          onCancel: select.cancelable
              ? () => selectN.respondSelectCounter(
                  const [],
                  generation: generation,
                )
              : null,
        );
      case SelectType.sort:
        return CardSelector(
          select: select,
          onSelect: (sequences) =>
              selectN.respondSortCard(sequences, generation: generation),
          onCancel: () => selectN.respondSortCard([], generation: generation),
          onInspectCard: onInspectCard,
          myController: myController,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
