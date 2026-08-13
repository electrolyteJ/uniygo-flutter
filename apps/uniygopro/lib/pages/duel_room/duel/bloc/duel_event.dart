
import 'package:duelink/duelink.dart';

import '../../../../models/field_card.dart';

/// 决斗场景事件：UI 意图 / 生命周期 / 服务绑定。
///
/// 服务器消息（含阶段广播）由 Bloc 订阅并转成事件进入事件队列，
/// 核心（DuelFieldStore）只负责归约，不再直接订阅服务流。
sealed class DuelEvent {
  const DuelEvent();
}

/// Bloc 内部事件：核心逻辑在事件处理器之外发生了变化
/// （服务器消息回调、Timer 回调、异步预加载完成等），请求发射新状态。
final class DuelCoreChanged extends DuelEvent {
  const DuelCoreChanged();
}

/// Bloc 内部事件：回合计时器心跳（每秒一次，仅 timeLeft 变化）。
/// 与 [DuelCoreChanged] 分开，让页面级订阅可以跳过计时 tick。
final class DuelTimerTicked extends DuelEvent {
  const DuelTimerTicked();
}

/// Bloc 内部事件：服务器原始消息（onServerMessage 流转入）。
/// 处理在核心 [DuelFieldStore.handleServerMessage] 中完成。
final class DuelServerMessageReceived extends DuelEvent {
  final YgoStocMsg msg;
  const DuelServerMessageReceived(this.msg);
}

/// Bloc 内部事件：服务器阶段广播（onDuelPhaseMessage 独立流，
/// 不在 GameMsg 内）。
final class DuelPhaseMessageReceived extends DuelEvent {
  final DuelPhase phase;
  const DuelPhaseMessageReceived(this.phase);
}

// ── 生命周期 / 绑定 ──────────────────────────────────────────

final class DuelServiceBound extends DuelEvent {
  final IDuelService service;
  const DuelServiceBound(this.service);
}

/// 通知 Bloc 开始订阅服务器消息流（须在 IDuelService.connect 之后）。
///
/// [phaseNameResolver] 由 UI 层注入，用于把阶段广播本地化后写入决斗日志；
/// 这样 Bloc 与核心都不需要持有 BuildContext。
final class DuelServerMessagesBound extends DuelEvent {
  final String? Function(DuelPhase phase)? phaseNameResolver;
  const DuelServerMessagesBound({this.phaseNameResolver});
}

final class DuelPlayersSynced extends DuelEvent {
  final List<PlayerInfo> players;
  const DuelPlayersSynced(this.players);
}

final class DuelKnownSelfExtraDeckCodesSet extends DuelEvent {
  final List<int> codes;
  const DuelKnownSelfExtraDeckCodesSet(this.codes);
}

final class DuelResetRequested extends DuelEvent {
  const DuelResetRequested();
}

final class DuelLocalUiCleared extends DuelEvent {
  const DuelLocalUiCleared();
}

// ── 检视 / 区域浏览 / 菜单 ───────────────────────────────────

final class DuelCardInspected extends DuelEvent {
  final int code;
  const DuelCardInspected(this.code);
}

final class DuelInspectorDismissed extends DuelEvent {
  const DuelInspectorDismissed();
}

final class DuelConfirmPanelDismissed extends DuelEvent {
  const DuelConfirmPanelDismissed();
}

final class DuelZoneInspectHandled extends DuelEvent {
  final String zoneKey;
  const DuelZoneInspectHandled(this.zoneKey);
}

final class DuelZoneBrowserOpened extends DuelEvent {
  final String zoneKey;
  const DuelZoneBrowserOpened(this.zoneKey);
}

final class DuelZoneBrowserClosed extends DuelEvent {
  const DuelZoneBrowserClosed();
}

final class DuelZoneBrowserCardInspected extends DuelEvent {
  final int sequence;
  final int code;
  const DuelZoneBrowserCardInspected(this.sequence, this.code);
}

final class DuelPhaseMenuToggled extends DuelEvent {
  const DuelPhaseMenuToggled();
}

// ── 卡片点击 ─────────────────────────────────────────────────

final class DuelHandCardTapped extends DuelEvent {
  final int sequence;
  final int code;
  const DuelHandCardTapped(this.sequence, this.code);
}

final class DuelFieldCardTapped extends DuelEvent {
  final FieldCard? fieldCard;
  final int? code;
  const DuelFieldCardTapped(this.fieldCard, this.code);
}

// ── 就地选择（inline select）─────────────────────────────────

final class DuelInlineSelectConfirmed extends DuelEvent {
  const DuelInlineSelectConfirmed();
}

final class DuelInlineSelectCancelled extends DuelEvent {
  const DuelInlineSelectCancelled();
}

final class DuelInlineUnselectFinished extends DuelEvent {
  const DuelInlineUnselectFinished();
}

// ── 选择题响应 ───────────────────────────────────────────────

final class DuelSelectCardResponded extends DuelEvent {
  final List<int> sequences;
  const DuelSelectCardResponded(this.sequences);
}

final class DuelSelectChainResponded extends DuelEvent {
  final int sequence;
  const DuelSelectChainResponded(this.sequence);
}

final class DuelSelectEffectYnResponded extends DuelEvent {
  final bool yes;
  const DuelSelectEffectYnResponded(this.yes);
}

final class DuelSelectYesNoResponded extends DuelEvent {
  final bool yes;
  const DuelSelectYesNoResponded(this.yes);
}

final class DuelSelectPositionResponded extends DuelEvent {
  final int position;
  const DuelSelectPositionResponded(this.position);
}

final class DuelSelectOptionResponded extends DuelEvent {
  final int sequence;
  const DuelSelectOptionResponded(this.sequence);
}

final class DuelSelectPlaceKeyResponded extends DuelEvent {
  final String key;
  const DuelSelectPlaceKeyResponded(this.key);
}

final class DuelSelectUnselectCardResponded extends DuelEvent {
  final int? sequence;
  const DuelSelectUnselectCardResponded(this.sequence);
}

final class DuelSelectCounterResponded extends DuelEvent {
  final List<int> values;
  const DuelSelectCounterResponded(this.values);
}

final class DuelSelectSumResponded extends DuelEvent {
  final List<int> sequences;
  const DuelSelectSumResponded(this.sequences);
}

final class DuelSortCardResponded extends DuelEvent {
  final List<int> indices;
  const DuelSortCardResponded(this.indices);
}

final class DuelAnnounceCardResponded extends DuelEvent {
  final int code;
  const DuelAnnounceCardResponded(this.code);
}
