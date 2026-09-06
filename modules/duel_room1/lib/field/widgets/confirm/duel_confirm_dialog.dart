import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:biz/duel/field/card_confirm_state.dart';
import 'package:biz/duel/field/duel_field_state.dart';
import 'package:duel_room1/field/widgets/confirm/confirm_cards_panel.dart';
import 'package:duel_room1/field/widgets/confirm/confirm_floating_card.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';

Rect clampFloatingCardRect(Rect desired, Rect safeRect) {
  final width = desired.width.clamp(0.0, safeRect.width).toDouble();
  final height = desired.height.clamp(0.0, safeRect.height).toDouble();
  final left = desired.left
      .clamp(safeRect.left, safeRect.right - width)
      .toDouble();
  final top = desired.top
      .clamp(safeRect.top, safeRect.bottom - height)
      .toDouble();
  return Rect.fromLTWH(left, top, width, height);
}

/// 确认展示弹层：订阅 cardConfirm 子状态、决定呈现方式（确认卡列表
/// 停靠面板 / 卡组顶·额外卡组顶浮动卡片，二者可同时）并组装具体确认组件。
///
/// 确认消息只展示、不回包、**不阻塞对局**（区别于选择窗口）：
/// 卡列表面板是右停靠的非模态面板（[ConfirmCardsPanel]），面板外点击
/// 穿透到场地；关闭分发（dismissConfirmPanel）收口在这里。卡名解析直连
/// duelFieldProvider 缓存。浮动卡片的定位需要场地槽位的屏幕坐标，
/// 由页面注入 [slotRectOf] 查询闭包（Flame 锚点更新不走页面重建，
/// 传值会过期，闭包在 build 时读取最新锚点）。
///
/// 对照 duel_room2 的 field/duel_field_page.dart 内联实现。
/// 页面在 Stack 中直接插入本组件：无活跃确认时渲染空盒子；
/// 有确认时 Positioned.fill 铺满（bare Stack 无命中子节点时不挡点击，
/// 两个确认组件都自身可点、空白处穿透）。
class DuelConfirmDialog extends ConsumerWidget {
  const DuelConfirmDialog({
    super.key,
    required this.slotRectOf,
    this.onInspectCard,
    this.onInspectPanelCard,
    this.showConfirmPanel = true,
    this.showFloatingPreview = true,
  });

  /// 区域槽位（如 `self_deck`/`opp_extra`）的屏幕坐标查询；
  /// 锚点未就绪时返回 null，浮动卡片退到角落兜底位。
  final Rect? Function(String zoneKey) slotRectOf;

  /// 点击确认卡查看详情（与 DuelSelectPrompt 同一检视链路）；
  /// 为 null 时卡片不响应点击。
  final void Function(int code)? onInspectCard;
  final void Function(int code)? onInspectPanelCard;
  final bool showConfirmPanel;
  final bool showFloatingPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = ref.watch(cardConfirmProvider.select((s) => s.confirmPanel));
    final preview = ref.watch(
      cardConfirmProvider.select(
        (s) => (
          isFloat: s.isFloatPreview,
          owner: s.floatPreviewOwner,
          isExtra: s.floatPreviewIsExtra,
          codes: s.floatPreviewCodes,
          index: s.floatPreviewIndex,
        ),
      ),
    );
    final visiblePanel = showConfirmPanel ? panel : null;
    final visiblePreview = showFloatingPreview && preview.isFloat;
    if (visiblePanel == null && !visiblePreview) return const SizedBox.shrink();
    // 卡名缓存到达时刷新面板/浮卡文字。
    ref.watch(duelFieldProvider.select((s) => s.cardInfoVersion));
    final myController = ref.watch(
      duelFieldProvider.select((s) => s.myController),
    );
    final confirmN = ref.read(cardConfirmProvider.notifier);
    String cardNameBuilder(int code) =>
        ref.read(duelFieldProvider.notifier).getCardInfo(code)?.name ??
        'Card #$code';

    return Positioned.fill(
      child: Stack(
        children: [
          if (visiblePanel != null)
            ConfirmCardsPanel(
              // 按 ConfirmPanel 实例换 key：每次新确认重播进场动画。
              key: ObjectKey(visiblePanel),
              title: visiblePanel.title,
              codes: visiblePanel.codes,
              cardNameBuilder: cardNameBuilder,
              onDismiss: confirmN.dismissConfirmPanel,
              onInspectCard: onInspectPanelCard ?? onInspectCard,
            ),
          // 下标越界（codes 变短等瞬态）时不渲染，避免 RangeError。
          if (visiblePreview && preview.index < preview.codes.length)
            _buildFloatPreview(
              context,
              preview,
              myController,
              cardNameBuilder,
              confirmN,
            ),
        ],
      ),
    );
  }

  /// 卡组顶/额外顶的逐张浮动预览：锚定对应区域槽位上方，
  /// 锚点未就绪时退到己方右下/对方右上的角落兜底位。
  Widget _buildFloatPreview(
    BuildContext context,
    ({bool isFloat, int owner, bool isExtra, List<int> codes, int index})
    preview,
    int myController,
    String Function(int code) cardNameBuilder,
    CardConfirmNotifier confirmN,
  ) {
    final spec = DuelRoomLayout.of(context);
    final isSelf = preview.owner == myController;
    final zoneKey = preview.isExtra
        ? (isSelf ? 'self_extra' : 'opp_extra')
        : (isSelf ? 'self_deck' : 'opp_deck');
    final zoneRect = slotRectOf(zoneKey);

    final size = const Size(150, 270);
    late final Rect desiredRect;
    if (zoneRect != null) {
      desiredRect = Rect.fromLTWH(
        zoneRect.center.dx - size.width / 2,
        zoneRect.top - size.height,
        size.width,
        size.height,
      );
    } else {
      if (isSelf) {
        desiredRect = Rect.fromLTWH(
          spec.safeRect.right - size.width - 30,
          spec.safeRect.bottom - size.height - 30,
          size.width,
          size.height,
        );
      } else {
        desiredRect = Rect.fromLTWH(
          spec.safeRect.right - size.width - 30,
          spec.safeRect.top + 120,
          size.width,
          size.height,
        );
      }
    }
    final rect = clampFloatingCardRect(desiredRect, spec.safeRect);

    return Positioned.fromRect(
      rect: rect,
      child: ConfirmFloatingCard(
        codes: preview.codes,
        // 当前展示下标由 notifier 计时推进（每卡 750ms + 500ms 收尾），
        // 组件自身不再持有逐张计时与自动关闭逻辑。
        currentIndex: preview.index,
        title: preview.isExtra ? '额外卡组顶部' : '卡组顶部',
        cardNameBuilder: cardNameBuilder,
        onDismiss: confirmN.dismissConfirmPanel,
        onInspectCard: onInspectCard,
      ),
    );
  }
}
