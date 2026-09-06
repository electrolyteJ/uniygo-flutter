import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';

import 'package:resource_data/deck_info.dart';

class DeckSelector extends StatelessWidget {
  final bool enabled;
  final List<DeckInfo> decks;

  /// 卡组列表首载是否仍在进行（区分「加载中」与「真空」）。
  final bool deckListLoading;
  final String? selectedDeckName;

  /// 自身玩家类型（非观战即决斗者，tag 模式座位 2/3 为
  /// player3/player4，同样算决斗者）。
  final PlayerType selfType;
  final ValueChanged<String?>? onSelectDeck;
  final VoidCallback? onEditDeck;
  final List<String>? invalidationResult;

  const DeckSelector({
    super.key,
    this.enabled = true,
    required this.decks,
    this.deckListLoading = false,
    required this.selectedDeckName,
    required this.selfType,
    required this.onSelectDeck,
    this.onEditDeck,
    this.invalidationResult,
  });

  @override
  Widget build(BuildContext context) {
    final invalid = invalidationResult?.isNotEmpty == true;
    // 决斗者判断按身份而非座位号：tag 模式座位 2/3 也是决斗者。
    final isPlayer = selfType != PlayerType.observer;
    final hasSelectedDeck =
        selectedDeckName != null &&
        decks.any((d) => d.deckName == selectedDeckName);
    if (!isPlayer) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        // 半透明底：融入等待室半透明弹窗，透出下方场地。
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
              Icon(Icons.style, size: 14, color: Colors.blueGrey.shade400),
              const SizedBox(width: 6),
              Text(
                '卡组',
                style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
              ),
              const SizedBox(width: 6),
              if (hasSelectedDeck)
                Flexible(
                  child: Text(() {
                      final deck = decks.firstWhere((d) => d.deckName == selectedDeckName);
                      return '主: ${deck.mainCount}  额: ${deck.extraCount}  副: ${deck.sideCount}';
                    }(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (decks.isEmpty)
            Text(
              // 首载进行中与「真空」区分，避免加载期间闪空提示。
              deckListLoading ? '卡组加载中…' : '没有可用卡组，请先在主页创建卡组',
              style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12),
            )
          else
            Row(children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade800,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blueGrey.shade600),
                  ),
                  child: DropdownButton<String>(
                    // 卡组重命名/删除后所选名可能已不在列表中，
                    // value 逃逸会触发 DropdownButton 断言，逃逸时回退为未选中。
                    value: hasSelectedDeck ? selectedDeckName : null,
                    underline: const SizedBox.shrink(),
                    isExpanded: true,
                    iconSize: 20,
                    isDense: true,
                    dropdownColor: Colors.blueGrey.shade800,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    items: decks.map((d) {
                      return DropdownMenuItem(
                        value: d.deckName,
                        child: Text(
                          d.deckName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: enabled ? onSelectDeck : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (hasSelectedDeck)
                Flexible(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: onEditDeck,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber.shade200,
                      side: BorderSide(color: Colors.amber.shade700),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      '编辑当前卡组',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ]),
          if (invalid)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          size: 14,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '卡组不合规',
                            style: TextStyle(
                              color: Colors.red.shade400,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...invalidationResult!.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(top: 2, left: 18),
                        child: Text(
                          '• $e',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.red.shade300,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // invalidationResult 三态：非空=不合规（上方红条），
          // 空列表=校验通过，null=未校验（房间未开启卡组检查或禁限表
          // 不可用，由服务端提交时兜底）——未校验给中性提示，不冒充合规。
          if (!invalid && invalidationResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.green.shade400,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '卡组合规',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.green.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (invalidationResult == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 14,
                    color: Colors.blueGrey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '卡组未校验',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.blueGrey.shade400,
                        fontSize: 12,
                      ),
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
