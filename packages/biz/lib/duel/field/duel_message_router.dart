import 'dart:async';
import 'package:applog/console.dart' as console;

import 'package:biz/service_providers.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duelink/duelink.dart';

import 'card_confirm_state.dart';
import 'duel_field_state.dart';
import 'field_overlay_state.dart';
import 'message_pump.dart';
import 'select_window_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'duel_message_router.g.dart';

/// 服务器消息路由器（按房间 ProviderScope 隔离）。
///
/// 取代原 DuelFieldController 的「消息分发」职责：在
/// duelServiceProvider.connect 之后调用 [DuelMessageRouter.start]，
/// 订阅对局消息流并把 MSG_* / STOC_* 分发到对应子状态 Notifier。
///
/// - 四个子状态（duelField / selectWindow / cardConfirm / fieldOverlay）
///   仍是唯一的状态持有者，写逻辑各归其 Notifier；
/// - 本 router 不持有任何 UI 状态，只做「流订阅 + 消息分发 + 音效」，
///   生命周期（取消订阅）交给 Riverpod 的 ref.onDispose；
/// - 跨状态的本地交互与菜单派生逻辑已内联到 DuelFieldPage。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。
@Riverpod(keepAlive: true)
class DuelMessageRouter extends _$DuelMessageRouter {
  StreamSubscription<YgoStocMsg>? _msgSub;
  String? Function(DuelPhase phase)? _phaseLabel;

  /// 消息节奏泵：观战追赶/开局爆发时把消息摊平成自适应节奏逐条消费；
  /// 空闲时 0ms 直通。start() 重建，随订阅一起回收。
  MessagePump<YgoStocMsg>? _pump;

  /// 当前对局是否为观战局（MSG_START 的 isObserver 捕获，start() 复位）。
  /// 「跳到当前局面」仅观战局生效，玩家对局的开局爆发不应被静默吞掉。
  bool _isObserverDuel = false;

  /// 节奏泵队列里是否有尚未消费的 MSG_WIN。
  ///
  /// AI 服务端常在关连接前的最后一个 TCP 段里才发结果：stage 流
  /// （不经过泵）已瞬时跳 RoomDuelEnded → RoomNotJoined，而 MSG_WIN
  /// 还在泵里排队，duelResult 尚未写入。房间页的断连出口判定
  /// （shouldHoldForDuelResult / shouldPromptDisconnect）必须把这个
  /// 「已在途中」的结果算上，否则正常结算被误判成意外断连。
  bool _hasPendingWin = false;

  /// 泵队列中是否有待消费的 MSG_WIN（见 [_hasPendingWin]）。
  bool get hasPendingWin => _hasPendingWin;

  /// 断连结算收尾：把泵里排队的消息同步静音消费完（含 MSG_WIN），
  /// 终局状态（duelResult 等）立即落位，结算弹窗不用等节奏泵排空，
  /// 也不播断连后的「鬼魂动画」。
  void flushPendingMessages() {
    _pump?.flushSilent();
  }

  DuelFieldState get _board => ref.read(duelFieldProvider);
  DuelFieldNotifier get _boardN => ref.read(duelFieldProvider.notifier);
  SelectWindowNotifier get _selectN => ref.read(selectWindowProvider.notifier);
  CardConfirmNotifier get _confirmN => ref.read(cardConfirmProvider.notifier);
  FieldOverlayNotifier get _overlayN => ref.read(fieldOverlayProvider.notifier);
  YgoSoundService get _sound => ref.read(ygoSoundServiceProvider);

  @override
  void build() {
    ref.onDispose(_cancelSubscriptions);
    // 运行时改设置即时生效（下一条入队/清场即按新模式）。
    ref.listen(ygoSettingsProvider, (_, _) => _applyReplaySettings());
  }

  void _cancelSubscriptions() {
    _msgSub?.cancel();
    _msgSub = null;
    _pump?.dispose();
    _pump = null;
  }

  /// 在 duelService.connect 之后调用：把服务绑定到需要回包的 Notifier，
  /// 并订阅对局消息流。
  ///
  /// [phaseLabel] 把阶段枚举本地化（l10n 依赖 BuildContext，由房间页注入），
  /// 用于「xx 开始。」的战报文案；不传则跳过阶段日志。
  ///
  /// 可重入：重复调用先取消旧订阅再重建，避免同一消息被分发两次。
  void start({String? Function(DuelPhase phase)? phaseLabel}) {
    _phaseLabel = phaseLabel;
    _cancelSubscriptions();
    _isObserverDuel = false;
    final service = ref.read(duelServiceProvider);
    _pump = MessagePump(consume: _handleServerMessage);
    _hasPendingWin = false;
    _applyReplaySettings();
    _msgSub = service.onServerMessage.listen(_onServerMessage);
  }

  /// 把观战回放设置写入节奏泵：jump 仅观战局生效。
  void _applyReplaySettings() {
    final s = ref.read(ygoSettingsProvider);
    _pump
      ?..speedFactor = s.replaySpeedFactor
      ..jumpToCurrent = s.spectateJumpToCurrent && _isObserverDuel;
  }

  /// 服务器消息入口（入队前的唯一分叉）：
  /// - STOC_TIME_LIMIT 直通：计时必须实时，不进节奏泵；
  /// - MSG_START 先清残留队列：Match 局间重开时丢弃上一局排队中的消息，
  ///   防止串台（与 MSG_START 分支的清状态逻辑对齐）；
  /// - 其余一律入泵，按自适应节奏消费。
  void _onServerMessage(YgoStocMsg msg) {
    final timeLimit = msg.timeLimit;
    if (timeLimit != null) {
      _boardN.handleTimeLimit(timeLimit);
      return;
    }
    final pump = _pump;
    if (pump == null) return;
    final gameMsg = msg.gameMsg;
    // MSG_WIN 入队时点留痕：节奏泵按序消费，若服务端在关连接前的
    // 最后一个 TCP 段里发了结果，日志可区分「服务端没发」与
    // 「发了但房间已退出、泵被销毁」两种断连无结算场景。
    if (gameMsg?.func == MSG_WIN) {
      _hasPendingWin = true;
      console.log(
        'router: MSG_WIN enqueued (pump pending=${pump.pendingCount})',
      );
    }
    if (gameMsg?.func == MSG_START) {
      // Match 局间重开：丢弃上一局排队中的消息，并按新局身份重估 jump。
      _isObserverDuel = switch (gameMsg!.innerMsg) {
        MsgStart m => m.isObserver,
        _ => false,
      };
      _hasPendingWin = false;
      pump.clear();
      _applyReplaySettings();
    }
    pump.enqueue(msg);
  }

  /// 泵消费入口：silent（观战「跳到当前局面」清场）时压掉音效。
  /// suppress 置位/复位在同一同步代码段内完成，无 await 交错，
  /// 不会影响共享实例上的其它音效。
  void _handleServerMessage(YgoStocMsg msg, {bool silent = false}) {
    if (msg.gameMsg?.func == MSG_WIN) _hasPendingWin = false;
    if (!silent) return _dispatchServerMessage(msg);
    _sound.suppress = true;
    try {
      _dispatchServerMessage(msg);
    } finally {
      _sound.suppress = false;
    }
  }

  /// 服务器原始消息分发：解码为对局事件后分发到对应状态。
  void _dispatchServerMessage(YgoStocMsg msg) {
    // STOC_TIME_LIMIT 不在 GameMsg 内，单独处理
    final timeLimit = msg.timeLimit;
    if (timeLimit != null) {
      _boardN.handleTimeLimit(timeLimit);
      return;
    }
    final gameMsg = msg.gameMsg;
    if (gameMsg == null) {
      // 非对局消息（STOC_DUEL_END / STOC_ERROR_MSG / STOC_JOIN_GAME 等）
      // 不归本分发器：分别由房间 stage 流与房间控制器处理，静默跳过。
      return;
    }
    if (gameMsg.innerMsg == null) {
      console.log('No game message payload ${gameMsg.func}');
      return;
    }
    final innerMsg = gameMsg.innerMsg as Object;
    if (innerMsg is MsgUnimplemented) {
      console.log(
        'Ignoring unsupported event: ${gameMsg.func} (${innerMsg.data.length} bytes)',
      );
      return;
    }
    switch (gameMsg.func) {
      // 决斗事件 start
      case MSG_START: // 对局开始（首局或 Match 局间）
        console.log(
          'handleServerMessage: MSG_START（对局开始） innerMsg=${gameMsg.innerMsg}',
        );
        // 新对局开始（首局或 Match 局间）：先清空上一局的作答/展示/浮层，
        // 避免 Match 局间状态串台，再由 handleStart 写入新局初始事实。
        _selectN.clearSelect();
        _confirmN.resetForNewDuel();
        _overlayN.clearLocalUi();
        _boardN.handleStart(innerMsg);
        _sound.playDuelStart();
        break;
      case MSG_NEW_TURN: // 新回合
        console.log(
          'handleServerMessage: MSG_NEW_TURN（新回合） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleNewTurn(innerMsg);
        _sound.playNewTurn();
        break;
      case MSG_NEW_PHASE: // 新阶段
        console.log(
          'handleServerMessage: MSG_NEW_PHASE（新阶段） innerMsg=${gameMsg.innerMsg}',
        );
        // 相位不再走 onDuelPhaseMessage 独立流（会超前于节奏泵中的画面），
        // 在消费到本条时同步更新：音效、阶段、战报、画面同源同节奏。
        // 阶段合法性（enableBp/enableM2/enableEp）只由服务端下发的
        // MSG_SELECT_IDLE_CMD / MSG_SELECT_BATTLE_CMD 驱动，这里不做本地推断。
        final phaseMsg = innerMsg as MsgNewPhase;
        final phase = DuelPhase.of(phaseMsg.rawPhase);
        _boardN.setPhaseFromStream(phase, _phaseLabel?.call(phase));
        _sound.playNewPhase();
        break;
      case MSG_WAITING: // 等待对手操作
        console.log(
          'handleServerMessage: MSG_WAITING（等待对手操作） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleWaiting(innerMsg as MsgWait);
        break;
      case MSG_ATTACK: // 攻击宣言
        console.log(
          'handleServerMessage: MSG_ATTACK（攻击宣言） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleAttack(innerMsg);
        _sound.playAttack();
        break;
      case MSG_DAMAGE: // 受到伤害
        console.log(
          'handleServerMessage: MSG_DAMAGE（受到伤害） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleDamage(innerMsg);
        _sound.playDamage();
        break;
      case MSG_RECOVER: // 生命回复
        console.log(
          'handleServerMessage: MSG_RECOVER（生命回复） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleRecover(innerMsg);
        _sound.playRecover();
        break;
      case MSG_LP_UPDATE: // 生命值同步
        console.log(
          'handleServerMessage: MSG_LP_UPDATE（生命值同步） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleLpUpdate(innerMsg);
        break;
      case MSG_PAY_LP_COST: // 支付生命值费用
        console.log(
          'handleServerMessage: MSG_PAY_LP_COST（支付生命值费用） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handlePayLife(innerMsg);
        _sound.playDamage();
        break;
      case MSG_CONFIRM_CARDS: // 确认展示的卡片
        console.log(
          'handleServerMessage: MSG_CONFIRM_CARDS（确认展示的卡片） innerMsg=${gameMsg.innerMsg}',
        );
        _handleConfirmCards(gameMsg.func, innerMsg as MsgConfirmCards);
        break;
      case MSG_CONFIRM_DECKTOP: // 确认卡组顶部
        console.log(
          'handleServerMessage: MSG_CONFIRM_DECKTOP（确认卡组顶部） innerMsg=${gameMsg.innerMsg}',
        );
        _handleConfirmCards(gameMsg.func, innerMsg as MsgConfirmCards);
        break;
      case MSG_CONFIRM_EXTRATOP: // 确认额外卡组顶部
        console.log(
          'handleServerMessage: MSG_CONFIRM_EXTRATOP（确认额外卡组顶部） innerMsg=${gameMsg.innerMsg}',
        );
        _handleConfirmCards(gameMsg.func, innerMsg as MsgConfirmCards);
        break;
      case MSG_CHAINING: // 连锁发动
        console.log(
          'handleServerMessage: MSG_CHAINING（连锁发动） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.setChainSealed(false);
        final chainMsg = innerMsg as MsgChaining;
        final name = _boardN.handleChaining(chainMsg);
        _boardN.addLog('连锁发动 $name。', player: chainMsg.location.controller);
        _sound.playChain();
        break;
      case MSG_CHAINED: // 连锁入链
        console.log(
          'handleServerMessage: MSG_CHAINED（连锁入链） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleChained(innerMsg as MsgChained);
        break;
      case MSG_CHAIN_SOLVING: // 连锁结算中
        console.log(
          'handleServerMessage: MSG_CHAIN_SOLVING（连锁结算中） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.setChainSealed(true);
        _boardN.handleChainSolving(innerMsg as MsgChainSolving);
        break;
      case MSG_CHAIN_SOLVED: // 连锁结算完成
        console.log(
          'handleServerMessage: MSG_CHAIN_SOLVED（连锁结算完成） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleChainSolved(innerMsg as MsgChainSolved);
        break;
      case MSG_CHAIN_END: // 连锁结束
        console.log(
          'handleServerMessage: MSG_CHAIN_END（连锁结束） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleChainEnd(innerMsg);
        // 连锁结束复位封印标志，避免残留 true 影响后续连锁叠层的显示判断。
        _boardN.setChainSealed(false);
        _sound.playChainEnd();
        break;
      case MSG_SUMMONING: // 正在召唤
        console.log(
          'handleServerMessage: MSG_SUMMONING（正在召唤） innerMsg=${gameMsg.innerMsg}',
        );
        final summonMsg = innerMsg as MsgSummoning;
        final name = _boardN.handleSummoning(summonMsg);
        _boardN.addLog('正在召唤 $name。', player: summonMsg.location.controller);
        _sound.playSummon();
        break;
      case MSG_SUMMONED: // 召唤完成
        console.log(
          'handleServerMessage: MSG_SUMMONED（召唤完成） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleSummonFinished('召唤');
        break;
      case MSG_SP_SUMMONING: // 正在特殊召唤
        console.log(
          'handleServerMessage: MSG_SP_SUMMONING（正在特殊召唤） innerMsg=${gameMsg.innerMsg}',
        );
        final msg = innerMsg as MsgSpSummoning;
        _boardN.handleSummonPreparing(
          msg.code,
          msg.location,
          actionLabel: '特殊召唤',
        );
        _sound.playSpecialSummon();
        break;
      case MSG_SP_SUMMONED: // 特殊召唤完成
        console.log(
          'handleServerMessage: MSG_SP_SUMMONED（特殊召唤完成） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleSummonFinished('特殊召唤');
        break;
      case MSG_FLIP_SUMMONING: // 正在反转召唤
        console.log(
          'handleServerMessage: MSG_FLIP_SUMMONING（正在反转召唤） innerMsg=${gameMsg.innerMsg}',
        );
        final msg = innerMsg as MsgFlipSummoning;
        _boardN.handleSummonPreparing(
          msg.code,
          msg.location,
          actionLabel: '反转召唤',
        );
        _sound.playFlipSummon();
        break;
      case MSG_FLIP_SUMMONED: // 反转召唤完成
        console.log(
          'handleServerMessage: MSG_FLIP_SUMMONED（反转召唤完成） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleSummonFinished('反转召唤');
        break;
      case MSG_BATTLE: // 战斗结算
        console.log(
          'handleServerMessage: MSG_BATTLE（战斗结算） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleBattle(innerMsg as MsgBattle);
        _sound.playBattle();
        break;
      case MSG_HINT: // 引擎提示
        console.log(
          'handleServerMessage: MSG_HINT（引擎提示） innerMsg=${gameMsg.innerMsg}',
        );
        final hintMsg = innerMsg as MsgHint;
        _boardN.handleHint(hintMsg);
        // 选择提示文案（selectMessage）在 MSG_SELECT_* 之前下发，缓存到
        // 选择窗口，供提示条/弹窗标题显示（如「请选择攻击对象」）。
        if (hintMsg.hintType == MsgHintType.selectMessage) {
          _selectN.setSelectHint(
            ref.read(stringsServiceProvider).systemString(hintMsg.hintData),
          );
          // 召唤/放置前的 selectMessage 提示的 hintData 实为待放置卡码
          // （如连接召唤百头龙前下发 44097050），缓存供 MSG_SELECT_PLACE
          // 自动选位识别连接怪兽、优先放入额外怪兽区；非卡码则清空残留。
          _selectN.setPendingPlaceCardCode(
            cardCodeFromDescriptionValue(hintMsg.hintData),
          );
        }
        break;
      case MSG_WIN: // 决出胜负
        console.log(
          'handleServerMessage: MSG_WIN（决出胜负） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleWin(innerMsg as MsgWin);
        // 只有本机真正获胜时才播放胜利音效（失败/投降不播）。
        if (_board.duelResult?['didWin'] == true) {
          _sound.playDuelWin();
        }
        break;
      case MSG_RETRY: // 操作无效需重试
        console.log(
          'handleServerMessage: MSG_RETRY（操作无效需重试） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.addLog('操作无效，请重新选择。');
        // 被拒绝的选择窗口要重开（宣言卡名等），否则窗口已被 respond* 清空、
        // 服务端仍在等待重试，对局会卡死。
        _selectN.handleRetry();
        break;
      case MSG_SHUFFLE_DECK: // 洗切卡组
        console.log(
          'handleServerMessage: MSG_SHUFFLE_DECK（洗切卡组） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleShuffleDeck(innerMsg);
        _sound.playShuffleDeck();
        break;
      case MSG_BECOME_TARGET: // 成为效果对象
        console.log(
          'handleServerMessage: MSG_BECOME_TARGET（成为效果对象） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleBecomeTarget(innerMsg as MsgBecomeTarget);
        break;
      case MSG_ATTACK_DISABLE: // 攻击被无效
        console.log(
          'handleServerMessage: MSG_ATTACK_DISABLE（攻击被无效） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleAttackDisabled();
        break;
      case MSG_CARD_TARGET: // 建立取对象关系（如「奈落的落穴」取对象）
        // 取对象关系（source→target）当前不驱动 UI 高亮，仅记录日志，
        // 避免落入 default 的 Unhandled 日志刷屏。
        console.log(
          'handleServerMessage: MSG_CARD_TARGET（建立取对象关系） innerMsg=${gameMsg.innerMsg}',
        );
        break;
      case MSG_DAMAGE_STEP_START: // 伤害步骤开始
        console.log(
          'handleServerMessage: MSG_DAMAGE_STEP_START（伤害步骤开始） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleDamageStepStart();
        _sound.playDamageStep();
        break;
      case MSG_DAMAGE_STEP_END: // 伤害步骤结束
        console.log(
          'handleServerMessage: MSG_DAMAGE_STEP_END（伤害步骤结束） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleDamageStepEnd();
        break;
      // 决斗事件 end
      // 决斗场地  start
      case MSG_DRAW: // 抽牌
        {
          console.log(
            'handleServerMessage: MSG_DRAW（抽牌） innerMsg=${gameMsg.innerMsg}',
          );
          final msg = innerMsg as MsgDraw;
          _boardN.applyDraw(msg);
          _boardN.addLog('抽了 ${msg.count} 张卡。', player: msg.player);
        }
        _sound.playCardDraw();
        break;
      case MSG_UPDATE_DATA: // 批量区域数据更新
        console.log(
          'handleServerMessage: MSG_UPDATE_DATA（批量区域数据更新） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.applyUpdateData(innerMsg as MsgUpdateData);
        break;
      case MSG_UPDATE_CARD: // 单卡数据更新
        console.log(
          'handleServerMessage: MSG_UPDATE_CARD（单卡数据更新） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.applyUpdateCard(innerMsg as MsgUpdateCard);
        break;
      case MSG_RELOAD_FIELD: // 整场快照重建
        console.log(
          'handleServerMessage: MSG_RELOAD_FIELD（整场快照重建） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.applyReloadField(innerMsg as MsgReloadField);
        break;
      case MSG_MOVE: // 卡片移动
        console.log(
          'handleServerMessage: MSG_MOVE（卡片移动） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.applyMove(innerMsg as MsgMove);
        _sound.playCardDestroy();
        break;
      case MSG_FIELD_DISABLED: // 区域禁用状态更新
        {
          console.log(
            'handleServerMessage: MSG_FIELD_DISABLED（区域禁用状态更新） innerMsg=${gameMsg.innerMsg}',
          );
          final msg = innerMsg as MsgFieldDisabled;
          _boardN.applyFieldDisabled(msg);
          _boardN.addLog('区域禁用状态已更新。');
        }
        break;
      case MSG_POS_CHANGE: // 表示形式变更
        console.log(
          'handleServerMessage: MSG_POS_CHANGE（表示形式变更） innerMsg=${gameMsg.innerMsg}',
        );
        final card = _boardN.handlePosChange(innerMsg);
        // 卡名未知（卡密为 0 或尚未加载）时不要打出 "null 表示形式变更"。
        final posChangeName = card?.name;
        _boardN.addLog(
          posChangeName == null ? '卡片表示形式变更。' : '$posChangeName 表示形式变更。',
          player: card?.controller,
        );
        _sound.playPosChange();
        break;
      case MSG_SHUFFLE_HAND: // 洗切手牌
        console.log(
          'handleServerMessage: MSG_SHUFFLE_HAND（洗切手牌） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.applyShuffleHand(innerMsg as MsgShuffleHand);
        break;
      case MSG_SHUFFLE_EXTRA: // 洗额外卡组
        console.log(
          'handleServerMessage: MSG_SHUFFLE_EXTRA（洗额外卡组） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleShuffleExtra(innerMsg as MsgShuffleExtra);
        break;
      case MSG_SET: // 盖放卡片
        console.log(
          'handleServerMessage: MSG_SET（盖放卡片） innerMsg=${gameMsg.innerMsg}',
        );
        _boardN.handleSet(innerMsg as MsgSet);
        _sound.playSetCard();
        break;
      // 决斗场地  end
      // 选择事件  start
      case MSG_SELECT_IDLE_CMD: // 空闲指令（召唤/盖放/结束回合等）
        console.log(
          'handleServerMessage: MSG_SELECT_IDLE_CMD（空闲指令） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applyIdleCmd(innerMsg as MsgSelectIdleCmd);
        break;
      case MSG_SELECT_BATTLE_CMD: // 战斗指令（攻击/进 M2/结束回合等）
        console.log(
          'handleServerMessage: MSG_SELECT_BATTLE_CMD（战斗指令） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applyBattleCmd(innerMsg as MsgSelectBattleCmd);
        break;
      case MSG_SELECT_CARD: // 选择卡片
        console.log(
          'handleServerMessage: MSG_SELECT_CARD（选择卡片） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applySelectCard(innerMsg as MsgSelectCard);
        break;
      case MSG_SELECT_CHAIN: // 选择要连锁的卡
        console.log(
          'handleServerMessage: MSG_SELECT_CHAIN（选择要连锁的卡） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applySelectChain(innerMsg as MsgSelectChain);
        break;
      case MSG_SELECT_EFFECTYN: // 是否发动效果
        console.log(
          'handleServerMessage: MSG_SELECT_EFFECTYN（是否发动效果） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applySelectEffectYn(innerMsg as MsgSelectEffectYn);
        break;
      case MSG_SELECT_YES_NO: // 是否执行
        console.log(
          'handleServerMessage: MSG_SELECT_YES_NO（是否执行） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applySelectYesNo(innerMsg as MsgSelectYesNo);
        break;
      case MSG_SELECT_PLACE: // 选择放置位置
        console.log(
          'handleServerMessage: MSG_SELECT_PLACE（选择放置位置） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applySelectPlace(innerMsg as MsgSelectPlace);
        break;
      case MSG_SELECT_POSITION: // 选择表示形式
        console.log(
          'handleServerMessage: MSG_SELECT_POSITION（选择表示形式） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applySelectPosition(innerMsg as MsgSelectPosition);
        break;
      case MSG_SELECT_TRIBUTE: // 选择解放怪兽
        console.log(
          'handleServerMessage: MSG_SELECT_TRIBUTE（选择解放怪兽） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applySelectTribute(innerMsg as MsgSelectTribute);
        break;
      case MSG_SELECT_COUNTER: // 选择移除指示物
        console.log(
          'handleServerMessage: MSG_SELECT_COUNTER（选择移除指示物） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applySelectCounter(innerMsg as MsgSelectCounter);
        break;
      case MSG_SELECT_SUM: // 按等级合计选择
        console.log(
          'handleServerMessage: MSG_SELECT_SUM（按等级合计选择） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applySelectSum(innerMsg as MsgSelectSum);
        break;
      case MSG_SORT_CARD: // 卡排序
        console.log(
          'handleServerMessage: MSG_SORT_CARD（卡排序） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applySortCard(innerMsg as MsgSortCard);
        break;
      case MSG_SELECT_OPTION: // 选择选项
        console.log(
          'handleServerMessage: MSG_SELECT_OPTION（选择选项） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applySelectOption(innerMsg as MsgSelectOption);
        break;
      case MSG_ANNOUNCE_CARD: // 宣言卡名
        console.log(
          'handleServerMessage: MSG_ANNOUNCE_CARD（宣言卡名） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applyAnnounceCard(innerMsg as MsgAnnounceCard);
        break;
      case MSG_ANNOUNCE_NUMBER: // 宣言数值（如「名推理」宣言等级）
        console.log(
          'handleServerMessage: MSG_ANNOUNCE_NUMBER（宣言数值） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applyAnnounceNumber(innerMsg as MsgAnnounceNumber);
        break;
      case MSG_ANNOUNCE_ATTRIB: // 宣言属性
        console.log(
          'handleServerMessage: MSG_ANNOUNCE_ATTRIB（宣言属性） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applyAnnounceAttrib(innerMsg as MsgAnnounceAttrib);
        break;
      case MSG_ANNOUNCE_RACE: // 宣言种族
        console.log(
          'handleServerMessage: MSG_ANNOUNCE_RACE（宣言种族） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applyAnnounceRace(innerMsg as MsgAnnounceRace);
        break;
      case MSG_SELECT_UNSELECT_CARD: // 解除选择
        console.log(
          'handleServerMessage: MSG_SELECT_UNSELECT_CARD（解除选择） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applySelectUnselectCard(innerMsg as MsgSelectUnselectCard);
        break;
      case MSG_SELECT_DISFIELD: // 选择禁用区域
        console.log(
          'handleServerMessage: MSG_SELECT_DISFIELD（选择禁用区域） innerMsg=${gameMsg.innerMsg}',
        );
        _selectN.applySelectDisfield(innerMsg as MsgSelectPlace);
        break;
      // 选择事件  end
      case MSG_TOSS_COIN: // 抛硬币
        console.log(
          'handleServerMessage: MSG_TOSS_COIN（抛硬币） innerMsg=${gameMsg.innerMsg}',
        );
        {
          final toss = innerMsg as MsgToss;
          // ocgcore 硬币结果编码：0=反面，1=正面。
          final results = toss.results
              .map((r) => r == 1 ? '正面' : '反面')
              .join('、');
          _boardN.addLog('抛硬币：$results。', player: toss.player);
        }
        _sound.playCoinToss();
        break;
      case MSG_TOSS_DICE: // 掷骰子
        console.log(
          'handleServerMessage: MSG_TOSS_DICE（掷骰子） innerMsg=${gameMsg.innerMsg}',
        );
        {
          final toss = innerMsg as MsgToss;
          _boardN.addLog('掷骰子：${toss.results.join('、')}。', player: toss.player);
        }
        _sound.playDice();
        break;
      default: // 未处理的对局事件
        console.log('Unhandled  event: ${gameMsg.func}');
    }
  }

  /// MSG_CONFIRM_* 的呈现分发：先同步卡数据与战报（对局事实），
  /// 再按消息类型与卡所在区域选择高亮/浮动预览/确认面板。
  void _handleConfirmCards(int func, MsgConfirmCards msg) {
    _boardN.preloadCardInfos(msg.cards.map((card) => card.code));
    for (final card in msg.cards) {
      _boardN.syncConfirmedCard(card);
    }
    // 展示归属按卡的 controller 判定：MSG_CONFIRM_* 的 player 是
    // 「确认（查看）方」而非卡的持有方——对方效果向我展示其卡片时
    // player 仍是我方，按 player 会把标题误写成「我方 展示的卡片」。
    final owner =
        (msg.cards.isNotEmpty ? msg.cards.first.controller : msg.player) ==
                _board.myController
            ? '我方'
            : '对方';
    final zoneLabel = switch (func) {
      MSG_CONFIRM_DECKTOP => '卡组顶部卡片',
      MSG_CONFIRM_EXTRATOP => '额外卡组顶部卡片',
      _ => '卡片',
    };
    _boardN.addLog('确认了 $zoneLabel 的 ${msg.count} 张卡。', player: msg.player);
    _boardN.revealDeckToHandDraw(msg.cards);
    if (msg.skipPanel == 1) {
      console.log('Confirm cards: skip panel, only highlight.');
      return;
    }
    console.log(
      'Confirm cards: func=$func, count=${msg.count}, skipPanel=${msg.skipPanel}',
    );
    _confirmN.flushPending();

    if (func == MSG_CONFIRM_DECKTOP || func == MSG_CONFIRM_EXTRATOP) {
      final codes = msg.cards.map((card) => card.code).toList();
      final isExtra = func == MSG_CONFIRM_EXTRATOP;
      if (codes.length > 1) {
        // 多张：用确认面板一次性铺开全部卡。逐张浮动轮播任一时刻只能
        // 看到一张，玩家无法同时查看多张确认卡（如「卡组顶部 3 张」）。
        _confirmN.showConfirmPanel(title: '$owner $zoneLabel', codes: codes);
      } else {
        _confirmN.showFloatPreview(codes, msg.player, isExtra: isExtra);
      }
      return;
    }

    final fieldSlotKeys = <String>{};
    final handSequences = <int>{};
    final panelCodes = <int>{};

    for (final card in msg.cards) {
      final location = card.location;
      final controller = card.controller;
      final sequence = card.sequence;

      if ((location & (CARD_ZONE_DECK | CARD_ZONE_EXTRA)) != 0) {
        final isDeck = (location & CARD_ZONE_DECK) != 0;
        if (msg.count == 1) {
          _confirmN.showFloatPreview(
            msg.cards.map((card) => card.code).toList(),
            msg.player,
            isExtra: !isDeck,
          );
          return;
        }
        panelCodes.add(card.code);
      } else if (_board.isOnFieldLocation(location)) {
        final key = _board.fieldCardKey(controller, location, sequence);
        final current = _board.fieldCards[key];
        if (current != null && (current.position & POS_FACEUP) == 0) {
          fieldSlotKeys.add(key);
        }
      } else if ((location & CARD_ZONE_HAND) != 0) {
        handSequences.add(sequence);
      }
    }

    if (fieldSlotKeys.isNotEmpty || handSequences.isNotEmpty) {
      console.log(
        'Confirm cards: highlight field=${fieldSlotKeys.length} hand=${handSequences.length} panel=${panelCodes.length}',
      );
      _confirmN.scheduleConfirmedReveal(
        fieldSlotKeys: fieldSlotKeys,
        handSequences: handSequences,
        handOwner: msg.player,
        panelCodes: panelCodes,
        title: '$owner 展示的卡片',
      );
    } else if (panelCodes.isNotEmpty) {
      console.log('Confirm cards: show panel only, count=${panelCodes.length}');
      _confirmN.showConfirmPanel(
        title: '$owner 展示的卡片',
        codes: panelCodes.toList(),
      );
    }
  }
}
