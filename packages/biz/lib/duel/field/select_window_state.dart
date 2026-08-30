import 'dart:async';
import 'package:applog/console.dart' as console;

import 'package:biz/card_image_loader.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:duelink/duelink.dart';
import 'package:resource_data/card_info.dart' as pkg;

import 'duel_field_state.dart';
import '../models/battle_action.dart';
import '../models/field_card.dart';
import '../models/field_zone_key.dart';
import '../models/idle_action.dart';
import '../models/playmat_resolved_action.dart';
import '../models/select_state.dart';
import '../models/sum_check.dart' as sum_check;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'select_window_state.g.dart';

const Object _undefined = Object();

// ──────────────────────────────────────────
// MSG_ANNOUNCE_CARD 宣言条件（RPN 表达式操作码，ocgcore common.h）
// ──────────────────────────────────────────
const int _opcodeIsCode = 0x40000100;
const int _opcodeOr = 0x40000005;

/// 判断选择窗口是否为「恰好一个必选项且不可取消」的无脑单选，命中时可
/// 直接代为应答、无需弹窗（见 SelectWindowNotifier._tryAutoAnswer）。
///
/// 条件：card / tribute 两类「选卡」窗口（发动效果后「只有一个必选对象/
/// 解放」最常见，且应答格式统一为 selectMulti 下标）、唯一选项、必选
/// （min>=1）、不可取消、且指向本机玩家。其余窗口（yes/no、position、
/// option、chain 等）涉及真实取舍，不自动代答。
bool isForcedSingleSelect(SelectState window, int myController) {
  final isCardLike =
      window.type == SelectType.card || window.type == SelectType.tribute;
  if (!isCardLike) return false;
  if (window.options.length != 1) return false;
  if (window.min < 1) return false;
  if (window.cancelable) return false;
  // 只代答本机玩家的窗口（正常对局下客户端也只收到自己的选择窗口，
  // 此为防御性校验，避免误答对方请求）。
  if (window.player != myController) return false;
  return true;
}

/// 解析 MSG_ANNOUNCE_CARD 的 RPN 条件表达式，提取「只能宣言这些卡码」集合。
///
/// 返回 null 表示自由宣言（任意卡名）；否则为可宣言卡码集合。
/// 仅支持「ISCODE 谓词用 OR 连接」这一最常见形态（禁止令/抹杀之指名者/
/// 精神崩坏等）；含其它谓词（属性/种族/类型/系列）或其它运算时退回自由
/// 宣言，由服务端 is_declarable 校验，非法时回 MSG_RETRY。
Set<int>? _parseAnnounceDeclarableCodes(List<int> codes) {
  // Duel.AnnounceCard(player) 时 select_options = [TRUE] = [1] → 自由宣言。
  if (codes.length == 1 && codes[0] == 1) return null;

  final stack = <int>[];
  final declarable = <int>{};
  var supported = true;

  for (final token in codes) {
    if (token == _opcodeIsCode) {
      // 一元谓词：栈顶是其操作数（卡码）。
      if (stack.isNotEmpty) {
        final operand = stack.removeLast();
        if (operand > 0 && operand < 0x40000000) {
          declarable.add(operand);
        }
      }
      stack.add(1);
    } else if (token == _opcodeOr) {
      if (stack.isNotEmpty) stack.removeLast();
      if (stack.isNotEmpty) stack.removeLast();
      stack.add(1);
    } else if (token < 0x40000000) {
      stack.add(token); // 操作数（卡码等）
    } else {
      // 其它操作码（AND/NOT/NEG/算术/属性/种族/类型/系列等）：
      // 客户端不做完整求值，退回自由宣言。
      supported = false;
    }
  }

  if (!supported || declarable.isEmpty) return null;
  return declarable;
}

/// 支持就地选择的类型。排序/计数器/效果选项等交互复杂或没有
/// 场上位置，仍走 CardSelector 弹窗。
const _inlineSelectTypes = {
  SelectType.chain,
  SelectType.card,
  SelectType.tribute,
  SelectType.unselect,
  SelectType.sum,
};

/// 选择窗口状态：服务端下发、等待玩家作答、必须回包的选择题，不可变快照。
///
/// 「必须回包」是与确认展示（CardConfirmState，只展示不回包）的
/// 本质区别：这里每个窗口都阻塞对局，直到玩家作答或取消。
///
/// 字段全部只读，变更通过 [copyWith] 生成新快照；
/// MSG_SELECT_* 消息应用与 respond* 编码逻辑收敛在 [SelectWindowNotifier]。
class SelectWindowState {
  const SelectWindowState({
    this.selectedIdleActions = const [],
    this.selectedBattleActions = const [],
    this.enableBp = false,
    this.enableM2 = false,
    this.enableEp = false,
    this.currentSelect,
    this.inlineSelectedOptionIndices = const {},
    this.announceCardDeclarableCodes,
  });

  final List<IdleAction> selectedIdleActions;
  final List<BattleAction> selectedBattleActions;
  final bool enableBp;
  final bool enableM2;
  final bool enableEp;
  final SelectState? currentSelect;

  /// 就地选择（高亮手牌/场上卡代替 CardSelector 弹窗）时已勾选的选项下标。
  final Set<int> inlineSelectedOptionIndices;

  /// 宣言卡名的可宣言卡码集合；null 表示自由宣言（任意卡名）。
  final Set<int>? announceCardDeclarableCodes;

  SelectWindowState copyWith({
    List<IdleAction>? selectedIdleActions,
    List<BattleAction>? selectedBattleActions,
    bool? enableBp,
    bool? enableM2,
    bool? enableEp,
    Object? currentSelect = _undefined,
    Set<int>? inlineSelectedOptionIndices,
    Object? announceCardDeclarableCodes = _undefined,
  }) {
    return SelectWindowState(
      selectedIdleActions: selectedIdleActions ?? this.selectedIdleActions,
      selectedBattleActions:
          selectedBattleActions ?? this.selectedBattleActions,
      enableBp: enableBp ?? this.enableBp,
      enableM2: enableM2 ?? this.enableM2,
      enableEp: enableEp ?? this.enableEp,
      currentSelect: identical(currentSelect, _undefined)
          ? this.currentSelect
          : currentSelect as SelectState?,
      inlineSelectedOptionIndices:
          inlineSelectedOptionIndices ?? this.inlineSelectedOptionIndices,
      announceCardDeclarableCodes:
          identical(announceCardDeclarableCodes, _undefined)
          ? this.announceCardDeclarableCodes
          : announceCardDeclarableCodes as Set<int>?,
    );
  }

  // ──────────────────────────────────────────
  // 纯派生读取（不依赖战场状态）
  // ──────────────────────────────────────────

  bool get isWaitingForInput => currentSelect != null;
  bool get hasIdleCommandWindow => currentSelect?.type == SelectType.idleCmd;
  bool get hasBattleCommandWindow =>
      currentSelect?.type == SelectType.battleCmd;
  bool get hasPhaseCommandWindow =>
      hasIdleCommandWindow || hasBattleCommandWindow;

  bool ownsCurrentWindow(int player) => currentSelect?.player == player;
  bool canOpenPhaseMenuFor(int player) =>
      ownsCurrentWindow(player) && hasPhaseCommandWindow;

  int get inlineSelectedCount => inlineSelectedOptionIndices.length;

  bool get inlineSelectCanConfirm {
    final select = currentSelect;
    if (select == null) return false;
    if (select.type == SelectType.sum) {
      // SUM 窗口的可确认性由引擎校验决定（数量/合计两重约束），
      // 不是简单的 count >= min。
      return sum_check.sumSelectionIsValid(
        mustOptions: select.mustOptions,
        options: select.options,
        sumTarget: select.sumTarget,
        sumExact: select.sumExact,
        min: select.min,
        max: select.max,
        selectedIndices: inlineSelectedOptionIndices,
      );
    }
    return inlineSelectedOptionIndices.length >= select.min;
  }

  /// 当前为放置选择（MSG_SELECT_PLACE）时的可放置槽位 key 集合，
  /// 供场地组件直接高亮对应槽位。
  Set<String> get placeTargetFieldKeys {
    final select = currentSelect;
    if (select?.type != SelectType.place) return const {};
    return {
      for (final option in select!.options)
        if (option.zone == CARD_ZONE_MZONE || option.zone == CARD_ZONE_SZONE)
          zoneKeyOf(option.controller, option.zone, option.sequence),
    };
  }

  /// 就地选择的提示文案。无当前选择窗口时返回空串
  /// （selector 会在 clearSelect 后的空状态下重新求值，不能在这里崩）。
  String get inlineSelectHint {
    final select = currentSelect;
    if (select == null) return '';
    final count = inlineSelectedOptionIndices.length;
    // 引擎下发的选择提示优先（如「请选择攻击对象」）；多选时附推进度。
    final hint = select.hint;
    if (hint != null && hint.isNotEmpty) {
      return select.max > 1 ? '$hint ($count/${select.max})' : hint;
    }
    switch (select.type) {
      case SelectType.chain:
        return '选择要发动连锁的卡';
      case SelectType.place:
        // 放置选择（MSG_SELECT_PLACE/DISFIELD）：可选槽位已高亮在场地。
        // 注意：duel_room1/2 的 SelectPromptLayer 对 place 模式自带文案，
        // 此分支主要服务 duel_room3 的通用横幅（DuelSelectOverlay 对所有
        // 窗口类型都展示 inlineSelectHint）。
        return select.options.length <= 1
            ? '请选择放置区域'
            : '请选择放置区域（可选 ${select.options.length} 处）';
      case SelectType.tribute:
        return select.max == 1 ? '请选择解放的怪兽' : '选择解放的怪兽 ($count/${select.max})';
      case SelectType.unselect:
        return '已选择 $count 张卡，点卡切换，满足条件后完成';
      case SelectType.sum:
        return select.sumExact
            ? '选择卡使合计等于 ${select.sumTarget}'
            : '按等级合计选择卡 ($count/${select.max})';
      case SelectType.counter:
        return '选择要移除的指示物（共 ${select.counterRequired} 个）';
      default:
        return select.max == 1
            ? '请选择 1 张卡'
            : '选择 ${select.min}-${select.max} 张卡 ($count/${select.max})';
    }
  }
}

/// 选择窗口的 Notifier：持有全部 MSG_SELECT_* / MSG_SORT_CARD /
/// MSG_ANNOUNCE_CARD 的消息应用逻辑，以及 respond* 回包编码。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。
@Riverpod(keepAlive: true)
class SelectWindowNotifier extends _$SelectWindowNotifier {
  late YgoDataService _dataService;
  IDuelService? _duelService;

  /// 窗口序号计数器：只增不减（reset 也不归零），
  /// 保证跨窗口、跨对局的陈旧 UI 响应都能被识别并丢弃。
  int _generationCounter = 0;

  /// 最近一次 MSG_ANNOUNCE_CARD 的原始消息：MSG_RETRY 时据此重开窗口。
  MsgAnnounceCard? _lastAnnounceCard;

  /// 最近一次 MSG_HINT selectMessage 的选择提示文案，待下一个选择窗口消费。
  String? _pendingSelectHint;

  /// 最近一次 MSG_HINT selectMessage 解析出的待放置卡码（如连接召唤前
  /// 服务端下发的被召唤卡码），待下一个选择窗口消费；用于自动选位时
  /// 识别连接怪兽并优先放入额外怪兽区。
  int? _pendingPlaceCardCode;

  @override
  SelectWindowState build() {
    _dataService = ref.watch(dataServiceProvider);
    _duelService = ref.watch(duelServiceProvider);
    return const SelectWindowState();
  }

  /// 读取战场状态（myController / fieldCards / 战斗演出清理）。
  DuelFieldState get _board => ref.read(duelFieldProvider);

  // ──────────────────────────────────────────
  // 选择响应
  // ──────────────────────────────────────────

  /// 分配递增的 generation，返回新窗口快照（不写 state）。
  /// 需要连同其他字段一次性写入 state 的 apply* 使用该 helper。
  SelectState _nextWindow(SelectState select) {
    _generationCounter++;
    return select.copyWith(generation: _generationCounter);
  }

  /// 缓存引擎下发的选择提示文案（MSG_HINT selectMessage），
  /// 供紧随其后的 MSG_SELECT_* 选择窗口消费。
  void setSelectHint(String? hint) {
    _pendingSelectHint = (hint == null || hint.isEmpty) ? null : hint;
  }

  /// 缓存引擎下发的待放置卡码（MSG_HINT selectMessage 的 hintData 解析为
  /// 卡码时），供紧随其后的 MSG_SELECT_PLACE 自动选位判断卡种（连接怪兽
  /// 优先额外怪兽区）；非卡码提示传 null 以清掉残留。
  void setPendingPlaceCardCode(int? code) {
    _pendingPlaceCardCode = code;
  }

  /// 打开一个新的选择窗口：分配递增的 generation、预热卡图缓存。
  /// 所有 apply* 一律经此入口（或 [_nextWindow]）开窗，
  /// 保证 generation 语义统一。
  /// （unselect 窗口的初始勾选由 applySelectUnselectCard 在开窗后补写。）
  ///
  /// 开窗前先过 [_tryAutoAnswer]：若该窗口是「恰好一个必选项且不可取消」
  /// 的无脑选择，直接代为应答、不弹窗，减少无意义点击。
  void _openWindow(SelectState select) {
    final pending = _pendingSelectHint;
    _pendingSelectHint = null;
    // 待放置卡码与提示文案同为「下一个窗口消费」语义；非放置窗口消费不到，
    // 在此统一清掉，避免陈旧卡码污染后续（可能跨回合的）放置窗口。
    _pendingPlaceCardCode = null;
    final withHint = pending == null ? select : select.copyWith(hint: pending);
    if (_tryAutoAnswer(withHint)) {
      // 已自动应答：清掉可能残留的窗口，不占用 generation。
      state = state.copyWith(
        currentSelect: null,
        inlineSelectedOptionIndices: const {},
      );
      return;
    }
    final window = _nextWindow(withHint);
    state = state.copyWith(
      currentSelect: window,
      inlineSelectedOptionIndices: const {},
    );
    _preloadSelectImages(window);
  }

  /// 单一必选项自动应答：命中 [isForcedSingleSelect] 时直接代为选择
  /// （下标 0）并返回 true；否则返回 false 走正常弹窗。
  bool _tryAutoAnswer(SelectState window) {
    if (_duelService == null) return false;
    if (!isForcedSingleSelect(window, _board.myController)) return false;
    final only = window.options.single;
    console.log(
      '_tryAutoAnswer: auto-select single forced ${window.type} '
      '(code=${only.code} c=${only.controller} z=${only.zone} s=${only.sequence})',
    );
    _sendResponse(CtosGameMsgResponse.selectMulti([0]));
    return true;
  }

  /// 记录当前等待玩家处理的选择请求，同时预热所有选项的卡图缓存。
  void setSelect(SelectState select) {
    _openWindow(select);
  }

  /// 预热 CardSelector 中所有卡片图片到 [CardImageLoader] 全局缓存。
  /// 选卡弹窗卡片约 92px 宽，按 256 目标宽度降采样解码，避免全尺寸
  /// 400px 图占内存。
  void _preloadSelectImages(SelectState select) {
    for (final opt in [...select.mustOptions, ...select.options]) {
      if (opt.code > 0) CardImageLoader.I.load(opt.code, targetWidth: 256);
    }
  }

  /// 清除当前选择请求。
  void clearSelect() {
    state = state.copyWith(
      currentSelect: null,
      inlineSelectedOptionIndices: const {},
      announceCardDeclarableCodes: null,
    );
  }

  /// 处理服务端 MSG_RETRY：重新打开刚被拒绝的宣言卡名窗口，让玩家重选。
  ///
  /// 宣言卡名的合法性由服务端 is_declarable 校验，客户端无法完全预判；
  /// respondAnnounceCard 回包后已 clearSelect，若服务端回 MSG_RETRY 而不重开
  /// 窗口，玩家将无从重试、对局卡死。其它窗口暂不重建（就地选择等都有
  /// 本地校验，触发 RETRY 罕见）。
  void handleRetry() {
    final last = _lastAnnounceCard;
    if (last != null && state.currentSelect == null) {
      applyAnnounceCard(last);
    }
  }

  void _sendResponse(CtosGameMsgResponse response) {
    _duelService?.playGameResponse(response);
  }

  /// generation 门卫：UI 回传的 generation 与当前窗口不一致时，
  /// 说明是陈旧菜单的迟到点击，记录日志并忽略。
  /// generation 为 null（旧调用方未传）时不做门卫。
  bool _acceptGeneration(int? generation, String method) {
    if (generation == null) return true;
    final current = state.currentSelect?.generation;
    if (generation != current) {
      console.log(
        '$method: stale generation $generation (current window generation=$current), ignored',
      );
      return false;
    }
    return true;
  }

  void respondIdleCmd(int sequence, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondIdleCmd')) return;
    _sendResponse(CtosGameMsgResponse.selectIdleCmd(sequence));
    clearSelect();
  }

  void respondBattleCmd(int sequence, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondBattleCmd')) return;
    _sendResponse(CtosGameMsgResponse.selectBattleCmd(sequence));
    clearSelect();
  }

  bool respondCurrentCommand(int sequence, {int? generation}) {
    if (state.hasIdleCommandWindow) {
      respondIdleCmd(sequence, generation: generation);
      return true;
    }
    if (state.hasBattleCommandWindow) {
      respondBattleCmd(sequence, generation: generation);
      return true;
    }
    return false;
  }

  void respondSelectCard(List<int> sequences, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectCard')) return;
    final select = state.currentSelect;
    if (select?.type == SelectType.card || select?.type == SelectType.tribute) {
      final summary = sequences
          .map((index) {
            if (select == null || index < 0 || index >= select.options.length) {
              return '#$index';
            }
            final option = select.options[index];
            return '#$index code=${option.code} c=${option.controller} z=${option.zone} s=${option.sequence}';
          })
          .join(', ');
      console.log('respondSelectCard: [$summary]');
    }
    _sendResponse(CtosGameMsgResponse.selectMulti(sequences));
    clearSelect();
  }

  void respondSelectChain(int sequence, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectChain')) return;
    _sendResponse(CtosGameMsgResponse.selectSingle(sequence));
    clearSelect();
  }

  void respondSelectEffectYn(bool yes, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectEffectYn')) return;
    _sendResponse(CtosGameMsgResponse.selectEffectYn(yes ? 1 : 0));
    clearSelect();
  }

  void respondSelectYesNo(bool yes, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectYesNo')) return;
    _sendResponse(CtosGameMsgResponse.selectEffectYn(yes ? 1 : 0));
    clearSelect();
  }

  void respondSelectPosition(int position, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectPosition')) return;
    _sendResponse(CtosGameMsgResponse.selectPosition(position));
    clearSelect();
  }

  void respondSelectOption(int sequence, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectOption')) return;
    _sendResponse(CtosGameMsgResponse.selectOption(sequence));
    clearSelect();
  }

  void respondSelectPlace(
    int player,
    int zone,
    int sequence, {
    int? generation,
  }) {
    if (!_acceptGeneration(generation, 'respondSelectPlace')) return;
    _sendResponse(
      CtosGameMsgResponse.selectPlace(
        CtosSelectPlace(player: player, zone: zone, sequence: sequence),
      ),
    );
    clearSelect();
  }

  void respondSelectTribute(List<int> sequences, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectTribute')) return;
    _sendResponse(CtosGameMsgResponse.selectMulti(sequences));
    clearSelect();
  }

  void respondSelectUnselectCard(int? sequence, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectUnselectCard')) return;
    console.log(
      sequence == null
          ? 'respondSelectUnselectCard: finish/cancel'
          : 'respondSelectUnselectCard: toggle #$sequence',
    );
    if (sequence == null) {
      _sendResponse(CtosGameMsgResponse.selectSingle(-1));
    } else {
      _sendResponse(CtosGameMsgResponse.selectMulti([sequence]));
    }
    clearSelect();
  }

  /// MSG_SELECT_COUNTER 回包（playerop.cpp:624-637）：
  /// 每卡一个 int16（窗口顺序），各值 ≤ 该卡指示物数，
  /// 且总和必须恰好等于需移除总数，否则服务端回 MSG_RETRY。
  /// 本地先行校验，违规直接拒绝并记录日志，避免无谓的往返重试。
  void respondSelectCounter(List<int> counts, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectCounter')) return;
    final select = state.currentSelect;
    if (select == null || select.type != SelectType.counter) {
      console.log('respondSelectCounter: no active COUNTER window, ignored');
      return;
    }
    if (counts.length != select.options.length) {
      console.log(
        'respondSelectCounter: expected ${select.options.length} values '
        '(one per card), got ${counts.length}; rejected',
      );
      return;
    }
    var sum = 0;
    for (var i = 0; i < counts.length; i++) {
      final limit = select.options[i].level ?? 0;
      if (counts[i] < 0 || counts[i] > limit) {
        console.log(
          'respondSelectCounter: value ${counts[i]} out of range 0..$limit '
          'for card #$i; rejected',
        );
        return;
      }
      sum += counts[i];
    }
    if (sum != select.counterRequired) {
      console.log(
        'respondSelectCounter: sum $sum != required ${select.counterRequired}; '
        'rejected',
      );
      return;
    }
    _sendResponse(CtosGameMsgResponse.selectCounter(counts));
    clearSelect();
  }

  /// MSG_SELECT_SUM 回包（playerop.cpp:690-751 select_with_sum_limit）：
  /// bvalue[0] = 含必选卡的总数；bvalue[1..mcount] 为必选占位（引擎不读）；
  /// bvalue[mcount+1..] = 仅相对可选段（state.options）的下标。
  /// selectMulti 的 count 字节即 bvalue[0]，故 payload =
  /// [占位 × mcount, ...可选段下标]。
  void respondSelectSum(List<int> selectableIndices, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectSum')) return;
    final select = state.currentSelect;
    if (select == null || select.type != SelectType.sum) {
      console.log('respondSelectSum: no active SUM window, ignored');
      return;
    }
    final seen = <int>{};
    for (final index in selectableIndices) {
      if (index < 0 || index >= select.options.length || !seen.add(index)) {
        console.log(
          'respondSelectSum: invalid indices $selectableIndices for '
          '${select.options.length} selectable cards; rejected',
        );
        return;
      }
    }
    final mcount = select.mustOptions.length;
    final payload = <int>[
      for (var i = 0; i < mcount; i++) 0,
      ...selectableIndices,
    ];
    console.log(
      'respondSelectSum: count=${mcount + selectableIndices.length} '
      '(must=$mcount + selected=${selectableIndices.length}) '
      'exact=${select.sumExact} target=${select.sumTarget} '
      'indices=$selectableIndices',
    );
    _sendResponse(CtosGameMsgResponse.selectMulti(payload));
    clearSelect();
  }

  void respondSortCard(List<int> indices, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSortCard')) return;
    _sendResponse(CtosGameMsgResponse.sortCard(indices));
    clearSelect();
  }

  void respondAnnounceCard(int code, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondAnnounceCard')) return;
    console.log('respondAnnounceCard: code=$code');
    _sendResponse(CtosGameMsgResponse.selectOption(code));
    clearSelect();
  }

  void respondAnnounceNumber(int index, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondAnnounceNumber')) return;
    console.log('respondAnnounceNumber: index=$index');
    _sendResponse(CtosGameMsgResponse.selectOption(index));
    clearSelect();
  }

  void respondAnnounceAttrib(int index, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondAnnounceAttrib')) return;
    console.log('respondAnnounceAttrib: index=$index');
    _sendResponse(CtosGameMsgResponse.selectOption(index));
    clearSelect();
  }

  void respondAnnounceRace(int index, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondAnnounceRace')) return;
    console.log('respondAnnounceRace: index=$index');
    _sendResponse(CtosGameMsgResponse.selectOption(index));
    clearSelect();
  }

  Future<List<pkg.CardInfo>> searchAnnounceCards(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return const <pkg.CardInfo>[];
    }
    final declarable = state.announceCardDeclarableCodes;
    final results = await _dataService.searchCards(trimmed);
    return results
        .where(
          (card) =>
              (declarable == null || declarable.contains(card.code)) &&
              card.name.trim().isNotEmpty &&
              card.alias != card.code,
        )
        .take(50)
        .toList(growable: false);
  }

  /// 加载受限宣言（如抹杀之指名者）的可宣言卡片信息。
  ///
  /// [state.announceCardDeclarableCodes] 为 null 时是自由宣言（任意卡名），
  /// 返回空列表；否则按卡码逐个查询，过滤掉查不到或名字为空的条目，
  /// 按卡码升序返回，供宣言弹窗直接展示可宣言卡列表。
  Future<List<pkg.CardInfo>> loadDeclarableCards() async {
    final declarable = state.announceCardDeclarableCodes;
    if (declarable == null || declarable.isEmpty) {
      return const <pkg.CardInfo>[];
    }
    final cards = <pkg.CardInfo>[];
    for (final code in declarable) {
      final card = await _dataService.getCard(code);
      if (card != null && card.name.trim().isNotEmpty) {
        cards.add(card);
      }
    }
    cards.sort((a, b) => a.code.compareTo(b.code));
    return cards;
  }

  // ──────────────────────────────────────────
  // 选择消息应用
  // ──────────────────────────────────────────

  /// 把手牌/场上可执行行动整理成 idle command 菜单。
  void applyIdleCmd(MsgSelectIdleCmd msg) {
    // 进入新的选择阶段时清除残留的动效（如攻击动画被反射镜力中断，怪兽破坏后无 MSG_BATTLE 结算）
    ref.read(duelFieldProvider.notifier).scheduleBattlePresentationClear();
    final actions = <IdleAction>[];
    for (final group in msg.commandGroups) {
      final type = group.type.index;
      for (final option in group.options) {
        actions.add(
          IdleAction(
            type: type,
            sequence: option.response,
            code: option.cardInfo.code,
            controller: option.cardInfo.controller,
            location: option.cardInfo.location,
            locationSequence: option.cardInfo.sequence,
            position: 0,
          ),
        );
      }
    }
    final activateDebug = actions
        .where((action) => action.type == 5)
        .map(
          (action) =>
              '#${action.sequence} code=${action.code} c=${action.controller} z=${action.location} s=${action.locationSequence}',
        )
        .join(', ');
    console.log(
      'applyIdleCmd: player=${msg.player} summon=${msg.commandGroups[0].options.length} '
      'spSummon=${msg.commandGroups[1].options.length} pos=${msg.commandGroups[2].options.length} '
      'mset=${msg.commandGroups[3].options.length} sset=${msg.commandGroups[4].options.length} '
      'activate=${msg.commandGroups[5].options.length} activateActions=[$activateDebug]',
    );
    state = state.copyWith(
      selectedIdleActions: actions,
      enableBp: msg.enableBp,
      enableEp: msg.enableEp,
      currentSelect: _nextWindow(
        SelectState(
          type: SelectType.idleCmd,
          player: msg.player,
          min: 1,
          max: 1,
        ),
      ),
      inlineSelectedOptionIndices: const {},
    );
  }

  /// 把战斗阶段可执行行动整理成 battle command 菜单。
  void applyBattleCmd(MsgSelectBattleCmd msg) {
    // 进入新的战斗指令选择时，若前一击未进入伤害计算（如怪兽在伤害计算前被效果破坏，
    // 无 MSG_BATTLE 结算），则清除残留的攻击动效。
    ref.read(duelFieldProvider.notifier).scheduleBattlePresentationClear();
    final actions = <BattleAction>[];
    for (final group in msg.commandGroups) {
      final type = group.type.index;
      for (final option in group.options) {
        actions.add(
          BattleAction(
            type: type,
            sequence: option.response,
            code: option.cardInfo.code,
            attackerController: option.cardInfo.controller,
            attackerLocation: option.cardInfo.location,
            attackerSequence: option.cardInfo.sequence,
            attackerPosition: 0,
            directAttack: option.directAttackable,
          ),
        );
      }
    }
    final attackDebug = actions
        .where((action) => action.type == 1)
        .map(
          (action) =>
              '#${action.sequence} code=${action.code} c=${action.attackerController} z=${action.attackerLocation} s=${action.attackerSequence} direct=${action.directAttack}',
        )
        .join(', ');
    console.log(
      'applyBattleCmd: player=${msg.player} activate=${actions.where((a) => a.type == 0).length} '
      'attack=${actions.where((a) => a.type == 1).length} attackActions=[$attackDebug] '
      'enableM2=${msg.enableM2} enableEp=${msg.enableEp}',
    );
    state = state.copyWith(
      selectedBattleActions: actions,
      enableM2: msg.enableM2,
      enableEp: msg.enableEp,
      currentSelect: _nextWindow(
        SelectState(
          type: SelectType.battleCmd,
          player: msg.player,
          min: 1,
          max: 1,
        ),
      ),
      inlineSelectedOptionIndices: const {},
    );
  }

  void applySelectCard(MsgSelectCard msg) {
    final options = <SelectOption>[];
    for (int i = 0; i < msg.count; i++) {
      options.add(
        SelectOption(
          code: msg.codes[i],
          controller: msg.locations[i].controller,
          zone: msg.locations[i].location,
          sequence: msg.locations[i].sequence,
        ),
      );
    }
    console.log(
      'applySelectCard: min=${msg.min} max=${msg.max} count=${msg.count} options='
      '${List.generate(msg.count, (i) => "#$i code=${msg.codes[i]} c=${msg.locations[i].controller} z=${msg.locations[i].location} s=${msg.locations[i].sequence}")}',
    );
    _openWindow(
      SelectState(
        type: SelectType.card,
        player: msg.player,
        options: options,
        min: msg.min,
        max: msg.max,
        cancelable: msg.cancelable != 0,
      ),
    );
  }

  void applySelectChain(MsgSelectChain msg) {
    // 官方客户端在无可连锁卡、非强制且非时点提示时直接回传 -1 放弃连锁，
    // 避免弹出空选择器阻塞对局。
    final isEmptyWindow =
        msg.chains.isEmpty && !msg.forced && msg.specialCount != 0x7f;
    if (isEmptyWindow) {
      console.log('applySelectChain: 无可连锁卡，自动放弃连锁');
      respondSelectChain(-1);
      return;
    }
    final options = <SelectOption>[];
    console.log('applySelectChain: ${msg.chains.length} options');
    for (final chain in msg.chains) {
      options.add(
        SelectOption(
          code: chain.code,
          controller: chain.location.controller,
          zone: chain.location.location,
          // 就地高亮需要真实场上/手牌位置；连锁响应值与选项下标一致，
          // 提交时仍按下标回传。
          sequence: chain.location.sequence,
          // 不使用 effectDescription 原始数值作为文案（对玩家无意义）。
        ),
      );
    }
    _openWindow(
      SelectState(
        type: SelectType.chain,
        player: msg.player,
        options: options,
        min: msg.forced ? 1 : 0,
        max: 1,
        cancelable: !msg.forced,
      ),
    );
  }

  void applySelectEffectYn(MsgSelectEffectYn msg) {
    _openWindow(
      SelectState(
        type: SelectType.effectYn,
        player: msg.player,
        options: [
          SelectOption(
            code: msg.code,
            controller: msg.location.controller,
            zone: msg.location.location,
            sequence: msg.location.sequence,
          ),
        ],
        min: 1,
        max: 1,
        effectDescription: msg.effectDescription,
      ),
    );
  }

  void applySelectYesNo(MsgSelectYesNo msg) {
    _openWindow(
      SelectState(
        type: SelectType.yesNo,
        player: msg.player,
        min: 1,
        max: 1,
        effectDescription: msg.effectDescription,
      ),
    );
  }

  void applySelectPlace(MsgSelectPlace msg) {
    // 待放置卡码由前一个 MSG_HINT selectMessage 缓存（_openWindow 会统一
    // 消费清空），先取出再开窗，供自动选位识别连接怪兽。
    final placeCardCode = _pendingPlaceCardCode;
    final options = _placeOptionsFromFieldMask(
      msg.field,
      selectingPlayer: msg.player,
      selectableWhenBitSet: false,
    );
    _openWindow(
      SelectState(
        type: SelectType.place,
        player: msg.player,
        options: options,
        min: msg.count,
        max: msg.count,
        cancelable: false,
      ),
    );
    _maybeAutoRespondPlace(options, msg.count, placeCardCode: placeCardCode);
  }

  /// 自动选择放置位置：仅当全局设置（自动选择怪兽/魔陷位置）开启、
  /// 且是「己方」的选位窗口时，替玩家选第一个可用空位。
  /// count==1 才自动回包；多位放置（如灵摆刻度）保持手动，
  /// 避免单格回包被服务端 MSG_RETRY。
  ///
  /// 连接怪兽例外：可选格含额外怪兽区（MZONE sequence 5/6）时优先放入
  /// EMZ。mask 按 bit 升序展开，主怪兽区永远排在 EMZ 前，朴素地取第一个
  /// 会把 Link 怪兽放进主区（占箭头位且导致「幻兽机 曙光女神百头龙」
  /// 这类依赖 EMZ 起手的展开断链）；与引擎自带 SIMPLE_AI 的选位偏好
  /// （playerop.cpp select_place：先 6 后 5）一致。是否连接怪兽由
  /// [placeCardCode]（MSG_HINT selectMessage 携带的卡码）查询卡表判断，
  /// 查不到时维持原行为。
  void _maybeAutoRespondPlace(
    List<SelectOption> options,
    int count, {
    int? placeCardCode,
  }) {
    if (count != 1 || options.isEmpty) return;
    if (state.currentSelect?.player != _board.myController) return;
    final settings = ref.read(ygoSettingsProvider);
    final first = options.first;
    final auto = first.zone == CARD_ZONE_MZONE
        ? settings.autoMonsterPosition
        : first.zone == CARD_ZONE_SZONE
        ? settings.autoSpellTrapPosition
        : false;
    if (!auto) return;
    var chosen = first;
    final isLinkSummon =
        chosen.zone == CARD_ZONE_MZONE &&
        placeCardCode != null &&
        (_dataService.getCardCached(placeCardCode)?.isLink ?? false);
    if (isLinkSummon) {
      final emz = options.where(
        (option) =>
            option.zone == CARD_ZONE_MZONE &&
            (option.sequence == 6 || option.sequence == 5),
      );
      if (emz.isNotEmpty) {
        chosen = emz.firstWhere(
          (option) => option.sequence == 6,
          orElse: () => emz.first,
        );
      }
    }
    console.log(
      'applySelectPlace: auto place controller=${chosen.controller} '
      'zone=${chosen.zone} sequence=${chosen.sequence}'
      '${isLinkSummon ? ' (link→EMZ)' : ''}',
    );
    respondSelectPlace(chosen.controller, chosen.zone, chosen.sequence);
  }

  void applySelectPosition(MsgSelectPosition msg) {
    final options = <SelectOption>[];
    for (final position in msg.availablePositions) {
      String label;
      switch (position) {
        case CardPosition.faceupAttack:
          label = '表侧攻击';
          break;
        case CardPosition.facedownAttack:
          label = '里侧攻击';
          break;
        case CardPosition.faceupDefense:
          label = '表侧守备';
          break;
        case CardPosition.facedownDefense:
          label = '里侧守备';
          break;
        default:
          label = position.name;
      }
      options.add(
        SelectOption(code: msg.code, position: position.value, label: label),
      );
    }
    _openWindow(
      SelectState(
        type: SelectType.position,
        player: msg.player,
        options: options,
        min: 1,
        max: 1,
      ),
    );
  }

  void applySelectTribute(MsgSelectTribute msg) {
    final options = <SelectOption>[];
    for (int i = 0; i < msg.count; i++) {
      options.add(
        SelectOption(
          code: msg.codes[i],
          controller: msg.locations[i].controller,
          zone: msg.locations[i].location,
          sequence: msg.locations[i].sequence,
          level: msg.levels[i],
        ),
      );
    }
    _openWindow(
      SelectState(
        type: SelectType.tribute,
        player: msg.player,
        options: options,
        min: msg.min,
        max: msg.max,
        cancelable: msg.cancelable != 0,
      ),
    );
  }

  /// MSG_SELECT_COUNTER 窗口：level = 该卡当前可用指示物数，
  /// counterRequired = 需移除的指示物总数（msg.min）。
  /// 响应编码见 [respondSelectCounter]（playerop.cpp:624-637）。
  void applySelectCounter(MsgSelectCounter msg) {
    final options = <SelectOption>[];
    for (int i = 0; i < msg.count; i++) {
      options.add(
        SelectOption(
          code: msg.codes[i],
          controller: msg.locations[i].controller,
          zone: msg.locations[i].location,
          sequence: msg.locations[i].sequence,
          level: msg.counterCounts[i],
        ),
      );
    }
    console.log(
      'applySelectCounter: player=${msg.player} required=${msg.min} '
      'cards=${msg.count} counterCounts=${msg.counterCounts}',
    );
    _openWindow(
      SelectState(
        type: SelectType.counter,
        player: msg.player,
        options: options,
        min: msg.min,
        max: msg.min,
        counterRequired: msg.min,
      ),
    );
  }

  /// MSG_SELECT_SUM 窗口（playerop.cpp:690-751）：
  /// options 只含可选段（selectable），必选段（must）进 mustOptions；
  /// level/level2 = 合计参数 o1/o2（o2==0 时 duelink 已归一为 level2==level1，
  /// 这里原样保留，sum_check 按引擎 get_sum_params 语义还原）。
  /// sumTarget = msg.levelSum；sumExact = msg.max == 0。
  /// 响应下标仅相对可选段，见 [respondSelectSum]。
  void applySelectSum(MsgSelectSum msg) {
    SelectOption toOption(MsgSelectSumInfo card) {
      return SelectOption(
        code: card.code,
        controller: card.location.controller,
        zone: card.location.location,
        sequence: card.location.sequence,
        level: card.level1,
        level2: card.level2,
      );
    }

    final mustOptions = msg.mustSelectCards
        .map(toOption)
        .toList(growable: false);
    final options = msg.selectableCards.map(toOption).toList(growable: false);
    console.log(
      'applySelectSum: player=${msg.player} target=${msg.levelSum} '
      'min=${msg.min} max=${msg.max} exact=${msg.max == 0} '
      'must=${mustOptions.length} selectable=${options.length}',
    );
    _openWindow(
      SelectState(
        type: SelectType.sum,
        player: msg.player,
        options: options,
        mustOptions: mustOptions,
        min: msg.min,
        max: msg.max,
        sumTarget: msg.levelSum,
        sumExact: msg.max == 0,
      ),
    );
  }

  void applySortCard(MsgSortCard msg) {
    final options = <SelectOption>[];
    for (int i = 0; i < msg.count; i++) {
      options.add(
        SelectOption(
          code: msg.codes[i],
          controller: msg.locations[i].controller,
          zone: msg.locations[i].location,
          sequence: msg.locations[i].sequence,
        ),
      );
    }
    _openWindow(
      SelectState(
        type: SelectType.sort,
        player: msg.player,
        options: options,
        min: msg.count,
        max: msg.count,
      ),
    );
  }

  void applySelectOption(MsgSelectOption msg) {
    final options = [
      for (var index = 0; index < msg.codes.length; index++)
        SelectOption(
          code: cardCodeFromDescriptionValue(msg.codes[index]) ?? 0,
          sequence: index,
          label: _resolveOptionLabel(msg.codes[index], index),
        ),
    ];
    _openWindow(
      SelectState(
        type: SelectType.option,
        player: msg.player,
        options: options,
        min: 1,
        max: 1,
      ),
    );
    // 卡信息未缓存时同步解析会落空为「选项 N」；开窗后异步补齐，
    // 到达时按 generation 门卫刷新当前窗口的选项文案。
    unawaited(_refreshOptionLabelsAsync(msg.codes));
  }

  /// 解析 MSG_SELECT_OPTION 选项的 desc 值（ocgcore GetDesc 语义）：
  /// - desc < 10000：strings.conf !system 系统文案（如「正面」「反面」）；
  /// - 否则 desc>>4 为卡码、desc&0xf 为 texts.str1~str16 下标
  ///   （脚本 aux.Stringid(code, i) 的效果选项文本）。
  /// 解析不到时兜底「选项 N」。
  String _resolveOptionLabel(int desc, int index) {
    final text = _optionTextFromCache(desc);
    return (text != null && text.isNotEmpty) ? text : '选项 ${index + 1}';
  }

  /// 仅从已就绪的数据源解析文案：系统字符串表 + 卡信息缓存。
  /// 解析不到返回 null（可能卡信息尚未缓存，由异步补齐）。
  String? _optionTextFromCache(int desc) {
    if (desc > 0 && desc < 10000) {
      return ref.read(stringsServiceProvider).systemString(desc);
    }
    final code = desc >> 4;
    final idx = desc & 0xf;
    if (code < 1000000 || code > 99999999) return null;
    final info = _dataService.getCardCached(code);
    if (info == null) return null;
    if (idx < info.strings.length) return info.strings[idx];
    return null;
  }

  /// 异步补齐选项文案：拉取未缓存的卡信息后，若当前窗口仍是同一次
  /// 选项选择（generation 未变），重写各选项 label。
  Future<void> _refreshOptionLabelsAsync(List<int> descs) async {
    final window = state.currentSelect;
    if (window == null || window.type != SelectType.option) return;
    // 需要异步拉取的卡码：desc 指向有效卡且缓存未命中。
    final codes = <int>{
      for (final desc in descs)
        if (desc >= 10000 &&
            (desc >> 4) >= 1000000 &&
            (desc >> 4) <= 99999999 &&
            _dataService.getCardCached(desc >> 4) == null)
          desc >> 4,
    };
    if (codes.isEmpty) return;
    for (final code in codes) {
      try {
        await _dataService.getCard(code);
      } catch (e) {
        console.log('applySelectOption: 拉取选项卡信息失败 code=$code: $e');
      }
    }
    final current = state.currentSelect;
    if (current == null ||
        current.type != SelectType.option ||
        current.generation != window.generation) {
      return; // 窗口已关闭或已被新窗口取代，丢弃迟到结果
    }
    state = state.copyWith(
      currentSelect: current.copyWith(
        options: [
          for (var index = 0; index < current.options.length; index++)
            SelectOption(
              code: current.options[index].code,
              controller: current.options[index].controller,
              zone: current.options[index].zone,
              sequence: current.options[index].sequence,
              label: _resolveOptionLabel(descs[index], index),
            ),
        ],
      ),
    );
  }

  void applyAnnounceCard(MsgAnnounceCard msg) {
    _lastAnnounceCard = msg;
    final declarable = _parseAnnounceDeclarableCodes(msg.codes);
    final player = msg.player;
    final rawLen = msg.codes.length;
    state = state.copyWith(
      announceCardDeclarableCodes: declarable,
      currentSelect: _nextWindow(
        SelectState(
          type: SelectType.announceCard,
          player: msg.player,
          min: 1,
          max: 1,
        ),
      ),
      inlineSelectedOptionIndices: const {},
    );
    console.log(
      'applyAnnounceCard: player=$player declarable=$declarable rawLen=$rawLen',
    );
  }

  void applyAnnounceNumber(MsgAnnounceNumber msg) {
    _applyAnnounceChoice(
      type: SelectType.announceNumber,
      player: msg.player,
      options: [
        for (final n in msg.numbers) SelectOption(code: n, label: '$n'),
      ],
      log: 'applyAnnounceNumber: player=${msg.player} numbers=${msg.numbers}',
    );
  }

  void applyAnnounceAttrib(MsgAnnounceAttrib msg) {
    _applyAnnounceChoice(
      type: SelectType.announceAttrib,
      player: msg.player,
      options: _announceMaskOptions(msg.available, _attributeLabels),
      log:
          'applyAnnounceAttrib: player=${msg.player} available=${msg.available}',
    );
  }

  void applyAnnounceRace(MsgAnnounceRace msg) {
    _applyAnnounceChoice(
      type: SelectType.announceRace,
      player: msg.player,
      options: _announceMaskOptions(msg.available, _raceLabels),
      log: 'applyAnnounceRace: player=${msg.player} available=${msg.available}',
    );
  }

  void _applyAnnounceChoice({
    required SelectType type,
    required int player,
    required List<SelectOption> options,
    required String log,
  }) {
    state = state.copyWith(
      currentSelect: _nextWindow(
        SelectState(
          type: type,
          player: player,
          options: options,
          min: 1,
          max: 1,
        ),
      ),
      inlineSelectedOptionIndices: const {},
    );
    console.log(log);
  }

  void applySelectUnselectCard(MsgSelectUnselectCard msg) {
    final options = <SelectOption>[];
    for (final card in msg.selectableCards) {
      options.add(
        SelectOption(
          code: card.code,
          controller: card.location.controller,
          zone: card.location.location,
          sequence: card.location.sequence,
        ),
      );
    }
    final initiallySelected = <int>[];
    final selectableCount = options.length;
    for (int i = 0; i < msg.selectedCards.length; i++) {
      final card = msg.selectedCards[i];
      options.add(
        SelectOption(
          code: card.code,
          controller: card.location.controller,
          zone: card.location.location,
          sequence: card.location.sequence,
        ),
      );
      initiallySelected.add(selectableCount + i);
    }
    console.log(
      'applySelectUnselectCard: min=${msg.min} max=${msg.max} '
      'selectable=${msg.selectableCards.length} selected=${msg.selectedCards.length} '
      'finishable=${msg.finishable} cancelable=${msg.cancelable}',
    );
    state = state.copyWith(
      currentSelect: _nextWindow(
        SelectState(
          type: SelectType.unselect,
          player: msg.player,
          options: options,
          min: msg.min,
          max: msg.max,
          cancelable: msg.cancelable,
          finishable: msg.finishable,
          immediateSingleToggle: true,
          initialSelectedIndices: initiallySelected,
        ),
      ),
      // 就地选择模式下同步已勾选项，保证高亮与「完成」门槛一致。
      inlineSelectedOptionIndices: {...initiallySelected},
    );
    _preloadSelectImages(state.currentSelect!);
  }

  /// MSG_SELECT_DISFIELD 与 MSG_SELECT_PLACE 共用引擎 field::select_place，
  /// flag 位 置位 = 不可用；回包校验为 `(sel & flag)` 即重试
  /// （playerop.cpp:460-467）。因此与 MSG_SELECT_PLACE 相同：
  /// 仅 flag 未置位的区域可选（selectableWhenBitSet: false）。
  void applySelectDisfield(MsgSelectPlace msg) {
    _openWindow(
      SelectState(
        type: SelectType.place,
        player: msg.player,
        options: _placeOptionsFromFieldMask(
          msg.field,
          selectingPlayer: msg.player,
          selectableWhenBitSet: false,
        ),
        min: msg.count,
        max: msg.count,
        cancelable: false,
      ),
    );
  }

  List<SelectOption> _placeOptionsFromFieldMask(
    int field, {
    required int selectingPlayer,
    required bool selectableWhenBitSet,
  }) {
    final options = <SelectOption>[];
    for (int bit = 0; bit < 32; bit++) {
      final bitSet = (field & (1 << bit)) != 0;
      if (selectableWhenBitSet ? !bitSet : bitSet) {
        continue;
      }
      final decoded = _decodePlaceBit(bit, selectingPlayer: selectingPlayer);
      if (decoded == null) continue;
      options.add(
        SelectOption(
          code: 0,
          controller: decoded.controller,
          zone: decoded.zone,
          sequence: decoded.sequence,
          label: _placeOptionLabel(
            selectingPlayer: selectingPlayer,
            controller: decoded.controller,
            zone: decoded.zone,
            sequence: decoded.sequence,
          ),
        ),
      );
    }
    return options;
  }

  ({int controller, int zone, int sequence})? _decodePlaceBit(
    int bit, {
    required int selectingPlayer,
  }) {
    final opponent = 1 - selectingPlayer;
    if (bit < 8) {
      return (
        controller: selectingPlayer,
        zone: CARD_ZONE_MZONE,
        sequence: bit,
      );
    }
    if (bit < 16) {
      return (
        controller: selectingPlayer,
        zone: CARD_ZONE_SZONE,
        sequence: bit - 8,
      );
    }
    if (bit < 24) {
      return (controller: opponent, zone: CARD_ZONE_MZONE, sequence: bit - 16);
    }
    if (bit < 32) {
      return (controller: opponent, zone: CARD_ZONE_SZONE, sequence: bit - 24);
    }
    return null;
  }

  String _placeOptionLabel({
    required int selectingPlayer,
    required int controller,
    required int zone,
    required int sequence,
  }) {
    final prefix = controller == selectingPlayer ? '我方' : '对方';
    if (zone == CARD_ZONE_MZONE) {
      if (sequence <= 4) {
        return '$prefix 怪兽区 ${sequence + 1}';
      }
      if (sequence == 5) {
        return '$prefix 额外怪兽区 1';
      }
      if (sequence == 6) {
        return '$prefix 额外怪兽区 2';
      }
      return '$prefix 怪兽区 ${sequence + 1}';
    }
    if (zone == CARD_ZONE_SZONE) {
      if (sequence <= 4) {
        return '$prefix 魔陷区 ${sequence + 1}';
      }
      if (sequence == 5) {
        return '$prefix 场地区';
      }
      return '$prefix 魔陷区 ${sequence + 1}';
    }
    return '$prefix 区域 ${sequence + 1}';
  }

  // ──────────────────────────────────────────
  // 就地选择（高亮手牌/场上卡代替 CardSelector 弹窗）
  //
  // 依赖战场状态（myController / fieldCards）的派生读取放在 Notifier 上。
  // ──────────────────────────────────────────

  /// 当前选择是否可以就地进行：类型受支持，且所有选项都落在
  /// 己方手牌或双方场上（怪兽/魔陷区）的可见位置。
  /// 任一选项落在卡组/墓地/除外/对方手牌等不可直接点击的区域时，
  /// 整体回退到弹窗选择。
  bool get inlineSelectActive =>
      resolveInlineSelectActive(state.currentSelect, _board);

  /// 就地选择中可点击的己方手牌下标。
  Set<int> get inlineSelectableHandSequences {
    if (!inlineSelectActive) return const {};
    return {
      for (final option in state.currentSelect!.options)
        if (option.zone == CARD_ZONE_HAND &&
            option.controller == _board.myController)
          option.sequence,
    };
  }

  /// 就地选择中可点击的场上卡 key（`controller_zone_sequence`）。
  Set<String> get inlineSelectableFieldKeys {
    if (!inlineSelectActive) return const {};
    return {
      for (final option in state.currentSelect!.options)
        if (option.zone == CARD_ZONE_MZONE || option.zone == CARD_ZONE_SZONE)
          zoneKeyOf(option.controller, option.zone, option.sequence),
    };
  }

  /// 就地选择中已勾选的手牌下标 / 场上卡 key（用于高亮样式）。
  Set<int> get inlineSelectedHandSequences {
    final select = state.currentSelect;
    if (select == null) return const {};
    return {
      for (final index in state.inlineSelectedOptionIndices)
        if (index < select.options.length)
          if (select.options[index] case final option
              when option.zone == CARD_ZONE_HAND &&
                  option.controller == _board.myController)
            option.sequence,
    };
  }

  Set<String> get inlineSelectedFieldKeys {
    final select = state.currentSelect;
    if (select == null) return const {};
    return {
      for (final index in state.inlineSelectedOptionIndices)
        if (index < select.options.length)
          if (select.options[index] case final option
              when option.zone == CARD_ZONE_MZONE ||
                  option.zone == CARD_ZONE_SZONE)
            zoneKeyOf(option.controller, option.zone, option.sequence),
    };
  }

  /// 点击可放置槽位（场地组件直接回调，key 为 `controller_zone_sequence`）。
  ///
  /// 保持单槽位响应语义：引擎 select_place 在 count>1 时期望
  /// 连续 count 组 (p,l,s)，单槽位回包会触发 MSG_RETRY；
  /// 此处保留单选行为但对 count>1 记录告警（多位放置需专门 UI）。
  void respondSelectPlaceKey(String key, {int? generation}) {
    final select = state.currentSelect;
    if (select?.type != SelectType.place) return;
    if (select!.max > 1) {
      console.log(
        'respondSelectPlaceKey: place window expects ${select.max} slots, '
        'single-slot tap may be retried by server',
      );
    }
    for (final option in select.options) {
      if (zoneKeyOf(option.controller, option.zone, option.sequence) == key) {
        respondSelectPlace(
          option.controller,
          option.zone,
          option.sequence,
          generation: generation,
        );
        return;
      }
    }
  }

  /// 选择提示的统一呈现方式：页面只消费该结果插入 SelectPromptLayer，
  /// 不再各自判断放置/就地/模态的互斥关系。
  SelectPromptMode get selectPromptMode =>
      resolveSelectPromptMode(state, _board);

  /// 手牌下标对应的就地选择选项下标；不可选时返回 null。
  int? inlineOptionIndexForHand(int sequence) {
    final select = state.currentSelect;
    if (select == null) return null;
    for (var i = 0; i < select.options.length; i++) {
      final option = select.options[i];
      if (option.zone == CARD_ZONE_HAND &&
          option.controller == _board.myController &&
          option.sequence == sequence) {
        return i;
      }
    }
    return null;
  }

  /// 场上卡对应的就地选择选项下标；不可选时返回 null。
  int? inlineOptionIndexForField(FieldCard card) {
    final select = state.currentSelect;
    if (select == null) return null;
    for (var i = 0; i < select.options.length; i++) {
      final option = select.options[i];
      if (option.controller == card.controller &&
          option.zone == card.zone &&
          option.sequence == card.sequence) {
        return i;
      }
    }
    return null;
  }

  /// 当前 SUM 窗口下已勾选集合是否通过引擎校验
  /// （数量约束 + select_sum_check1 / 精确合计窗口判定，
  /// 移植见 models/sum_check.dart）。[selectedIndices] 相对可选段
  /// （state.options）。非 SUM 窗口返回 false。
  bool isSumSelectionValid(Set<int> selectedIndices) {
    final select = state.currentSelect;
    if (select == null || select.type != SelectType.sum) return false;
    return sum_check.sumSelectionIsValid(
      mustOptions: select.mustOptions,
      options: select.options,
      sumTarget: select.sumTarget,
      sumExact: select.sumExact,
      min: select.min,
      max: select.max,
      selectedIndices: selectedIndices,
    );
  }

  /// 多选模式下切换某选项的勾选状态。
  /// 数量上限仅对非精确合计窗口生效（limit = max，
  /// 引擎对可选段的数量约束即 max；必选段另计）；
  /// 精确合计（sumExact）模式无数量上限，合法性由
  /// [isSumSelectionValid] 判定。
  void toggleInlineOption(int index) {
    final select = state.currentSelect;
    if (select == null) return;
    final next = {...state.inlineSelectedOptionIndices};
    if (next.contains(index)) {
      next.remove(index);
    } else {
      final countLimited = select.type != SelectType.sum || !select.sumExact;
      if (!countLimited || next.length < select.max) {
        next.add(index);
      }
    }
    state = state.copyWith(inlineSelectedOptionIndices: next);
  }

  /// 多选确认：按选项下标升序提交已勾选的卡。
  /// SUM 窗口先过引擎合计校验，非法组合不提交（避免 MSG_RETRY）。
  void confirmInlineSelect() {
    final select = state.currentSelect;
    if (select == null) return;
    final selected = state.inlineSelectedOptionIndices;
    if (select.type == SelectType.sum) {
      if (!isSumSelectionValid(selected)) {
        console.log(
          'confirmInlineSelect: SUM selection $selected does not satisfy '
          'target=${select.sumTarget} exact=${select.sumExact}, ignored',
        );
        return;
      }
      respondSelectSum(selected.toList()..sort());
      return;
    }
    if (!state.inlineSelectCanConfirm) return;
    respondInlineMulti(selected.toList()..sort());
  }

  /// 解除选择（unselect）的「完成」：向服务端确认当前勾选结果。
  void finishInlineUnselect() {
    final select = state.currentSelect;
    if (select?.type != SelectType.unselect || !state.inlineSelectCanConfirm) {
      return;
    }
    respondSelectUnselectCard(null);
  }

  /// 清空就地选择的勾选（不改动窗口本身，等价于「取消本次点选」，
  /// 而不是放弃整个选择窗口）。
  void clearInlineSelection() {
    if (state.inlineSelectedOptionIndices.isEmpty) return;
    state = state.copyWith(inlineSelectedOptionIndices: const {});
  }

  /// 取消当前就地选择（等价于弹窗的「取消」）。
  ///
  /// 引擎取消语义：可取消窗口回 -1 即被接受
  /// （playerop.cpp:271-275 select_card 响应分支：
  /// `returns.ivalue[0] == -1 && cancelable` → 通过；
  /// select_chain / select_unselect_card 同样以 -1 表示放弃）。
  /// 因此 min>=1 的可取消窗口一律回 selectSingle(-1)，
  /// 而不是空 selectMulti（空列表会被引擎当成 0 张选择而 MSG_RETRY）。
  /// min==0 的窗口空选择本身即合法应答，保持空列表行为。
  void cancelInlineSelect() {
    final select = state.currentSelect;
    if (select == null || !select.cancelable) return;
    switch (select.type) {
      case SelectType.chain:
        respondSelectChain(-1);
      case SelectType.unselect:
        respondSelectUnselectCard(null);
      default:
        if (select.min == 0) {
          respondSelectCard(const []);
        } else {
          _sendResponse(CtosGameMsgResponse.selectSingle(-1));
          clearSelect();
        }
    }
  }

  /// 按当前窗口类型把多选下标编码为对应的响应消息。
  void respondInlineMulti(List<int> indices) {
    switch (state.currentSelect?.type) {
      case SelectType.tribute:
        respondSelectTribute(indices);
      case SelectType.sum:
        respondSelectSum(indices);
      default:
        respondSelectCard(indices);
    }
  }
}

/// MSG_ANNOUNCE_ATTRIB 的属性位掩码 → 可读标签（按位值升序）。
const Map<int, String> _attributeLabels = {
  0x01: '地',
  0x02: '水',
  0x04: '炎',
  0x08: '风',
  0x10: '光',
  0x20: '暗',
  0x40: '神',
};

/// MSG_ANNOUNCE_RACE 的种族位掩码 → 可读标签（按位值升序）。
const Map<int, String> _raceLabels = {
  0x1: '战士',
  0x2: '魔法师',
  0x4: '天使',
  0x8: '恶魔',
  0x10: '不死',
  0x20: '机械',
  0x40: '水族',
  0x80: '炎族',
  0x100: '岩石',
  0x200: '鸟兽',
  0x400: '植物',
  0x800: '昆虫',
  0x1000: '雷族',
  0x2000: '龙',
  0x4000: '兽',
  0x8000: '兽战士',
  0x10000: '恐龙',
  0x20000: '鱼',
  0x40000: '海龙',
  0x80000: '爬虫类',
  0x100000: '念动力',
  0x200000: '幻神',
  0x400000: '创造神',
  0x800000: '幻龙',
  0x1000000: '电子界',
  0x2000000: '幻兽神',
};

/// 把声明位掩码展开为有序的 (code, label) 选项列表。
List<SelectOption> _announceMaskOptions(
  int available,
  Map<int, String> labels,
) {
  final options = <SelectOption>[];
  for (final entry in labels.entries) {
    if (available & entry.key != 0) {
      options.add(SelectOption(code: entry.key, label: entry.value));
    }
  }
  return options;
}

/// 选择提示呈现方式的纯函数版（跨 selectWindow+duelField 派生）。
/// 供 derived 的 selectPromptModeProvider 与 Notifier.selectPromptMode 共用。
SelectPromptMode resolveSelectPromptMode(
  SelectWindowState select,
  DuelFieldState board,
) {
  final current = select.currentSelect;
  // 阶段指令窗口由阶段菜单/场上操作处理，不出选择提示。
  if (current == null || select.hasPhaseCommandWindow) {
    return SelectPromptMode.none;
  }
  // place 一律走 place 提示层：即使可用槽位为空（如 EMZ 被共享占用、
  // 服务端位图异常导致 options 被清空），也只显示放置提示，不能落入
  // modal 的黑色遮罩，否则整页无法交互。
  if (current.type == SelectType.place) {
    return SelectPromptMode.place;
  }
  if (resolveInlineSelectActive(current, board)) {
    return SelectPromptMode.inline;
  }
  return SelectPromptMode.modal;
}

/// 就地选择可用性（纯函数版）：选项全部落在可直接点击的区域
/// （己方手牌 / 双方场上实际存在的卡）。
bool resolveInlineSelectActive(SelectState? select, DuelFieldState board) {
  if (select == null ||
      !_inlineSelectTypes.contains(select.type) ||
      select.options.isEmpty) {
    return false;
  }
  return select.options.every(
    (option) => _isInlineVisibleOptionIn(option, board),
  );
}

bool _isInlineVisibleOptionIn(SelectOption option, DuelFieldState board) {
  if (option.zone == CARD_ZONE_HAND) {
    return option.controller == board.myController;
  }
  if (option.zone == CARD_ZONE_MZONE || option.zone == CARD_ZONE_SZONE) {
    return board.fieldCards.containsKey(
      zoneKeyOf(option.controller, option.zone, option.sequence),
    );
  }
  // 卡组、墓地、额外、除外等区域不可直接点击，应通过弹窗选择
  return false;
}
