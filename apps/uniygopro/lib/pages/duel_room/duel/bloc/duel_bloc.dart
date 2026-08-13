
import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../duel_field_store.dart';
import 'duel_effect.dart';
import 'duel_event.dart';
import 'duel_state.dart';

/// 决斗场景 Bloc：UI 事件 → 核心逻辑归约 → 发射 [DuelState] 快照。
///
/// 核心逻辑（[DuelFieldStore]）保持可变实现，通过 [DuelFieldStore.onChanged]
/// 桥接通知 Bloc：
/// - 在事件处理器内触发的变化会被合并，处理器结束时统一发射一次；
/// - 服务器消息/阶段广播由 Bloc 订阅并转成事件，经 [sequential] 变换器
///   严格按到达顺序逐个处理（连锁时序依赖消息顺序）；
/// - 在处理器外触发的其他变化（Timer、异步预加载）会转成
///   [DuelCoreChanged] 内部事件，走正常事件队列发射。
class DuelBloc extends Bloc<DuelEvent, DuelState> {
  DuelBloc({DuelFieldStore? core}) : this._(core ?? DuelFieldStore());

  DuelBloc._(this._core) : super(DuelState.fromCore(_core, 0)) {
    _core.onChanged = _onCoreChanged;
    _core.onTimerTick = _onCoreTimerTick;
    _core.onEffect = _handleCoreEffect;

    on<DuelCoreChanged>((event, emit) => emit(_snapshot()));
    on<DuelTimerTicked>(
      (event, emit) => emit(_snapshot(isTimerTick: true)),
    );

    // 服务器消息：进入事件队列，按序处理。
    _register<DuelServerMessageReceived>(
      (e) => _core.handleServerMessage(e.msg),
      transformer: sequential(),
    );
    _register<DuelPhaseMessageReceived>(
      (e) => _core.applyPhase(e.phase, _phaseNameResolver?.call(e.phase)),
      transformer: sequential(),
    );

    // 生命周期 / 绑定
    _register<DuelServiceBound>((e) {
      _service = e.service;
    });
    _register<DuelServerMessagesBound>(
      (e) {
        _phaseNameResolver = e.phaseNameResolver;
        _bindServerStreams();
      },
    );
    _register<DuelPlayersSynced>((e) => _core.syncPlayers(e.players));
    _register<DuelKnownSelfExtraDeckCodesSet>(
      (e) => _core.setKnownSelfExtraDeckCodes(e.codes),
    );
    _register<DuelResetRequested>((e) {
      _unbindServerStreams();
      _core.reset();
    });
    _register<DuelLocalUiCleared>((e) => _core.clearLocalUi());

    // 检视 / 区域浏览 / 菜单
    _register<DuelCardInspected>((e) => _core.inspectCard(e.code));
    _register<DuelInspectorDismissed>((e) => _core.dismissInspector());
    _register<DuelConfirmPanelDismissed>((e) => _core.dismissConfirmPanel());
    _register<DuelZoneInspectHandled>((e) => _core.handleZoneInspect(e.zoneKey));
    _register<DuelZoneBrowserOpened>((e) => _core.openZoneBrowser(e.zoneKey));
    _register<DuelZoneBrowserClosed>((e) => _core.closeZoneBrowser());
    _register<DuelZoneBrowserCardInspected>(
      (e) => _core.inspectZoneBrowserCard(e.sequence, e.code),
    );
    _register<DuelPhaseMenuToggled>((e) => _core.togglePhaseMenu());

    // 卡片点击
    _register<DuelHandCardTapped>(
      (e) => _core.handleHandCardTap(e.sequence, e.code),
    );
    _register<DuelFieldCardTapped>(
      (e) => _core.handleFieldCardTap(e.fieldCard, e.code),
    );

    // 就地选择
    _register<DuelInlineSelectConfirmed>((e) => _core.confirmInlineSelect());
    _register<DuelInlineSelectCancelled>((e) => _core.cancelInlineSelect());
    _register<DuelInlineUnselectFinished>((e) => _core.finishInlineUnselect());

    // 选择题响应
    _register<DuelSelectCardResponded>(
      (e) => _core.respondSelectCard(e.sequences),
    );
    _register<DuelSelectChainResponded>(
      (e) => _core.respondSelectChain(e.sequence),
    );
    _register<DuelSelectEffectYnResponded>(
      (e) => _core.respondSelectEffectYn(e.yes),
    );
    _register<DuelSelectYesNoResponded>(
      (e) => _core.respondSelectYesNo(e.yes),
    );
    _register<DuelSelectPositionResponded>(
      (e) => _core.respondSelectPosition(e.position),
    );
    _register<DuelSelectOptionResponded>(
      (e) => _core.respondSelectOption(e.sequence),
    );
    _register<DuelSelectPlaceKeyResponded>(
      (e) => _core.respondSelectPlaceKey(e.key),
    );
    _register<DuelSelectUnselectCardResponded>(
      (e) => _core.respondSelectUnselectCard(e.sequence),
    );
    _register<DuelSelectCounterResponded>(
      (e) => _core.respondSelectCounter(e.values),
    );
    _register<DuelSelectSumResponded>(
      (e) => _core.respondSelectSum(e.sequences),
    );
    _register<DuelSortCardResponded>(
      (e) => _core.respondSortCard(e.indices),
    );
    _register<DuelAnnounceCardResponded>(
      (e) => _core.respondAnnounceCard(e.code),
    );
  }

  final DuelFieldStore _core;
  int _revision = 0;
  bool _handling = false;
  bool _pendingDirty = false;
  IDuelService? _service;
  StreamSubscription<YgoStocMsg>? _msgSub;
  StreamSubscription<DuelPhase>? _phaseSub;
  String? Function(DuelPhase phase)? _phaseNameResolver;

  /// 核心产生的一次性副作用中需要 UI 层处理的部分（音效等）。
  /// sync 广播流：监听器须在消息到达前挂好（页面 initState 订阅即可）。
  final _effects = StreamController<DuelEffect>.broadcast(sync: true);

  /// 表现类副作用流（音效），由页面订阅并映射到具体播放实现。
  Stream<DuelEffect> get effects => _effects.stream;

  /// 消化核心副作用：协议类（回包）内部处理，表现类转发给 UI。
  void _handleCoreEffect(DuelEffect effect) {
    switch (effect) {
      case DuelSendGameResponse(:final response):
        _service?.playGameResponse(response);
      case DuelSoundEffect():
        if (!_effects.isClosed) _effects.add(effect);
    }
  }

  DuelState _snapshot({bool isTimerTick = false}) =>
      DuelState.fromCore(_core, ++_revision, isTimerTick: isTimerTick);

  /// 订阅服务器消息流，转成事件进入队列。
  /// 重进决斗房间会再次触发绑定，因此先取消旧订阅。
  void _bindServerStreams() {
    _unbindServerStreams();
    _msgSub = _service?.onServerMessage.listen((msg) {
      if (isClosed) return;
      add(DuelServerMessageReceived(msg));
    });
    _phaseSub = _service?.onDuelPhaseMessage.listen((phase) {
      if (isClosed) return;
      add(DuelPhaseMessageReceived(phase));
    });
  }

  void _unbindServerStreams() {
    _msgSub?.cancel();
    _msgSub = null;
    _phaseSub?.cancel();
    _phaseSub = null;
  }

  /// 注册一个同步事件处理器：执行核心逻辑，若期间核心标记过变更，
  /// 则合并为一次状态发射。
  void _register<E extends DuelEvent>(
    void Function(E event) action, {
    EventTransformer<E>? transformer,
  }) {
    on<E>(
      (event, emit) {
      _handling = true;
      try {
        action(event);
      } finally {
        _handling = false;
      }
      if (_pendingDirty) {
        _pendingDirty = false;
        emit(_snapshot());
      }
      },
      transformer: transformer,
    );
  }

  void _onCoreChanged() {
    if (isClosed) return;
    if (_handling) {
      // 处理器内的变化合并，由处理器结束时统一发射。
      _pendingDirty = true;
      return;
    }
    // 处理器外的变化（Timer/异步预加载回调）走事件队列。
    add(const DuelCoreChanged());
  }

  void _onCoreTimerTick() {
    if (isClosed) return;
    if (_handling) {
      // 计时 tick 与其他变化撞在同一处理器内时按普通变化处理。
      _pendingDirty = true;
      return;
    }
    add(const DuelTimerTicked());
  }

  @override
  Future<void> close() {
    _unbindServerStreams();
    _phaseNameResolver = null;
    _core.onChanged = null;
    _core.onTimerTick = null;
    _core.onEffect = null;
    _effects.close();
    return super.close();
  }
}
