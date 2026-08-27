import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hud_theme.dart';

/// 选择窗口 HUD（MDPro3 风格）：顶部提示横幅 + 确认按钮 +
/// 模态对话框（是否/选项/表示形式）。
class DuelSelectOverlay extends ConsumerWidget {
  const DuelSelectOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final select = ref.watch(selectWindowProvider);
    final current = select.currentSelect;
    if (current == null) return const SizedBox.shrink();

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
        // 模态对话框
        Positioned.fill(child: _ModalForSelect(select: current)),
        // 就地多选的确认按钮
        if (_needsConfirm(current) && select.inlineSelectCanConfirm)
          Positioned(
            bottom: 130,
            left: 0,
            right: 0,
            child: Center(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: HudTheme.cyanDim,
                ),
                icon: const Icon(Icons.check, size: 18),
                label: Text('确认 (${select.inlineSelectedCount})'),
                onPressed: () {
                  final indices = select.inlineSelectedOptionIndices.toList()
                    ..sort();
                  ref
                      .read(selectWindowProvider.notifier)
                      .respondInlineMulti(indices);
                },
              ),
            ),
          ),
      ],
    );
  }

  bool _needsConfirm(SelectState select) {
    return switch (select.type) {
      SelectType.tribute ||
      SelectType.sum ||
      SelectType.counter ||
      SelectType.unselect =>
        true,
      SelectType.card => select.max > 1,
      _ => false,
    };
  }
}

class _ModalForSelect extends ConsumerWidget {
  const _ModalForSelect({required this.select});

  final SelectState select;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(selectWindowProvider.notifier);
    switch (select.type) {
      case SelectType.yesNo:
        return _TwoChoiceDialog(
          title: select.hint ?? '是否发动效果？',
          cancelable: select.cancelable,
          onYes: () => notifier.respondSelectYesNo(true),
          onNo: () => notifier.respondSelectYesNo(false),
        );
      case SelectType.effectYn:
        return _TwoChoiceDialog(
          title: select.hint ?? '是否发动效果？',
          cancelable: select.cancelable,
          onYes: () => notifier.respondSelectEffectYn(true),
          onNo: () => notifier.respondSelectEffectYn(false),
        );
      case SelectType.option:
      case SelectType.announceNumber:
      case SelectType.announceAttrib:
      case SelectType.announceRace:
        return _OptionDialog(select: select);
      case SelectType.position:
        return _PositionDialog(select: select);
      case SelectType.announceCard:
        return _AnnounceCardDialog(select: select);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _TwoChoiceDialog extends StatelessWidget {
  const _TwoChoiceDialog({
    required this.title,
    required this.cancelable,
    required this.onYes,
    required this.onNo,
  });

  final String title;
  final bool cancelable;
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
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
                if (cancelable)
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
      ),
    );
  }
}

class _OptionDialog extends ConsumerWidget {
  const _OptionDialog({required this.select});

  final SelectState select;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(selectWindowProvider.notifier);
    return Center(
      child: Container(
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
                        onPressed: () => notifier.respondSelectOption(i),
                        child: Text(select.options[i].label ?? '选项 ${i + 1}'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
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
    final entries = <(String, IconData, int)>[
      for (final option in select.options)
        if (option.position != null)
          (
            _positionLabel(option.position!),
            _positionIcon(option.position!),
            option.position!,
          ),
    ];
    return Center(
      child: Container(
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
                      onTap: () => notifier.respondSelectPosition(pos),
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

/// 卡网格选择对话框（墓地/除外等非场上区域的选择场景）。
class CardGridSelectDialog extends StatelessWidget {
  const CardGridSelectDialog({
    super.key,
    required this.title,
    required this.codes,
    required this.onSelect,
  });

  final String title;
  final List<int> codes;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 420),
        padding: const EdgeInsets.all(16),
        decoration: HudTheme.glowPanel(radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: HudTheme.title),
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
                itemCount: codes.length,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => onSelect(index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CardImage(code: codes[index], width: 82, height: 120),
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

/// 宣言卡名对话框（MSG_ANNOUNCE_CARD）：输入检索 + 候选列表。
class _AnnounceCardDialog extends ConsumerStatefulWidget {
  const _AnnounceCardDialog({required this.select});

  final SelectState select;

  @override
  ConsumerState<_AnnounceCardDialog> createState() =>
      _AnnounceCardDialogState();
}

class _AnnounceCardDialogState extends ConsumerState<_AnnounceCardDialog> {
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    final declarable = ref.watch(
      selectWindowProvider.select((s) => s.announceCardDeclarableCodes),
    );
    final notifier = ref.read(selectWindowProvider.notifier);
    return Center(
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxHeight: 460),
        padding: const EdgeInsets.all(16),
        decoration: HudTheme.glowPanel(radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.select.hint ?? '宣言一个卡名', style: HudTheme.title),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              style: HudTheme.body,
              decoration: const InputDecoration(
                hintText: '输入卡名检索…',
                hintStyle: HudTheme.caption,
                prefixIcon: Icon(
                  Icons.search,
                  color: HudTheme.textSecondary,
                  size: 18,
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _keyword = v),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: _DeclarableList(
                codes: declarable ?? const {},
                keyword: _keyword,
                onPick: (code) => notifier.respondAnnounceCard(code),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeclarableList extends ConsumerWidget {
  const _DeclarableList({
    required this.codes,
    required this.keyword,
    required this.onPick,
  });

  final Set<int> codes;
  final String keyword;
  final void Function(int code) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardN = ref.read(duelFieldProvider.notifier);
    final entries = <MapEntry<int, String>>[
      for (final code in codes)
        MapEntry(code, boardN.getCardInfo(code)?.name ?? '#$code'),
    ];
    final filtered = keyword.isEmpty
        ? entries
        : entries.where((e) => e.value.contains(keyword)).toList();
    return ListView.builder(
      shrinkWrap: true,
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
        return ListTile(
          dense: true,
          title: Text(entry.value, style: HudTheme.body),
          onTap: () => onPick(entry.key),
        );
      },
    );
  }
}
