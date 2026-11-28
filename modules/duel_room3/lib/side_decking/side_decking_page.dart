import 'package:biz/duel/room/duel_room_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/cyber_side_tokens.dart';
import '../widgets/duel_backdrop.dart';
import 'widgets/side_deck_editor_view.dart';
import 'widgets/side_waiting_view.dart';

/// 换备页：（match 局间）提交副卡组调整并等待下一局。
///
/// 页内两种形态，由 [DuelRoomState.sidingSubmitted] 切换：
/// - 编辑（Ardot 531:2 / 531:147）：主卡组网格 + 副卡组列表 + 换牌清单；
/// - 等待（Ardot 531:245）：卡组快照 + 就绪圈。
///
/// 观战者（[PlayerType.isDuelist] 为 false）只看到等待形态——他们没有卡组
/// 可换，但需要知道「局间正在换备、还要等多久」。
class SideDeckingPage3D extends ConsumerWidget {
  const SideDeckingPage3D({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(duelRoomProvider);
    final notifier = ref.read(duelRoomProvider.notifier);
    final isDuelist = room.selfType.isDuelist;
    // 已提交、或观战者 → 等待形态。
    final waiting = !isDuelist || room.sidingSubmitted;

    return DuelRoomBackdrop(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 设计基准 844×390。整页按比例缩放文字，让手机横屏与桌面
            // 窗口都能保持设计稿的疏密关系。
            final k =
                (constraints.maxWidth / CyberSideTokens.designSize.width)
                    .clamp(0.7, 2.6);
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(k)),
              child: waiting
                  ? SideWaitingView(
                      room: room,
                      onResubmit: notifier.resetSiding,
                      onCancelEdit: null,
                    )
                  : SideDeckEditorView(
                      room: room,
                      onSwapCards: (battleIndex, sideIndex, zone) =>
                          notifier.swapSidingCards(
                            battleIndex: battleIndex,
                            sideIndex: sideIndex,
                            battleZone: zone,
                          ),
                      onReset: notifier.resetSiding,
                      onSubmit: () => _submit(notifier),
                      onCancel: notifier.resetSiding,
                    ),
            );
          },
        ),
      ),
    );
  }

  /// 提交换备；返回失败原因（null=成功）。
  ///
  /// 不弹 SnackBar：设计稿把失败原因放在底栏的红色错误条里，比会飘走的
  /// SnackBar 更适合「照着错误提示改卡组」这类需要反复对照的场景。
  Future<String?> _submit(DuelRoomNotifier notifier) async {
    try {
      return await notifier.confirmSiding();
    } catch (e) {
      return '换备提交失败: $e';
    }
  }
}
