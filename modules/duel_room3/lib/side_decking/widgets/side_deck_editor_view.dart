import 'package:biz/duel/room/duel_room_state.dart';
import 'package:flutter/material.dart';
import 'package:resource_data/card_info.dart' show CardInfo;

import '../../theme/cyber_side_tokens.dart';
import '../../widgets/player_seats.dart';
import 'side_card.dart';
import 'side_card_text.dart';
import 'side_countdown.dart';
import 'side_deck_list.dart';
import 'side_top_bar.dart';
import 'side_zone.dart';

/// 换备编辑界面（Ardot 531:2「08z-01 换备 · 主界面」）。
///
/// 版式：844×390 三栏
/// ```
/// ┌ 顶条：[SIDE] 换备 / 副标 ──── GAME 1/3 · 比分 ──── [01:33] 换备计时 ┐
/// ├ 左栏（0–530）──────────────┬ 中栏（546–702）┬ 右栏（642–828）──────┤
/// │ MAIN DECK · 主卡组  40/40  │ SIDE 15 张     │ 换牌清单 · N 组      │
/// │  [搜索] [怪兽21][魔陷19]   │ ┌────────────┐ │ ┌──────────────────┐ │
/// │  ┌ 40 格 13 列网格 ─────┐  │ │▌增殖的G    │ │ │换入 …  换出 …    │ │
/// │  └──────────────────────┘  │ │▌灰流丽     │ │ │主40·副15 张数守恒│ │
/// │ EXTRA DECK · 额外卡组 15   │ │▌羽毛扇     │ │ └──────────────────┘ │
/// │  ┌ 15 格紫卡 ───────────┐  │ └────────────┘ │ READY · 双方就绪     │
/// │  └──────────────────────┘  │                │ [我 已提交][他 换备中]│
/// ├ 底注 ─────────────────────────────────── [提交卡组][取消编辑] ────┤
/// ```
///
/// 与旧实现（480px 竖排面板）的差异：卡组从「文字 chip 流式换行」变成
/// 「等宽卡面网格」，换备从「点卡片 + 选去向按钮」变成「点一张主卡 →
/// 点一张副卡完成互换」——后者才是三局两胜实际的操作节奏。
class SideDeckEditorView extends StatefulWidget {
  const SideDeckEditorView({
    super.key,
    required this.room,
    required this.onSwapCards,
    required this.onReset,
    required this.onSubmit,
    required this.onCancel,
  });

  final DuelRoomState room;

  /// 原子互换：主/额外卡组下标 ↔ 副卡组下标（一次 setState 完成）。
  final void Function(int battleIndex, int sideIndex, SidingZone battleZone)
  onSwapCards;

  final VoidCallback onReset;

  /// 提交换备；返回失败原因（null=成功）。
  final Future<String?> Function() onSubmit;

  /// 「取消编辑」：恢复基准构成。
  final VoidCallback onCancel;

  @override
  State<SideDeckEditorView> createState() => _SideDeckEditorViewState();
}

class _SideDeckEditorViewState extends State<SideDeckEditorView> {
  /// 主卡组里被选中、等待与副卡组互换的那一张（[DuelRoomState.sidingMain] 下标）。
  int? _selectedMainIndex;

  /// 副卡组里被选中的那一张，与 [_selectedMainIndex] 二选一。
  int? _selectedSideIndex;

  /// 提交中（含禁限校验网络往返）。
  bool _submitting = false;

  /// 上次提交失败的原因（设计稿 531:2 底部的红色错误条）。
  String? _error;

  @override
  void didUpdateWidget(covariant SideDeckEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 卡组被外部替换（重置 / 重新初始化）后，旧下标可能越界，清掉选中。
    final main = widget.room.sidingMain;
    final side = widget.room.sidingSide;
    if (_selectedMainIndex != null &&
        (main == null || _selectedMainIndex! >= main.length)) {
      _selectedMainIndex = null;
    }
    if (_selectedSideIndex != null &&
        (side == null || _selectedSideIndex! >= side.length)) {
      _selectedSideIndex = null;
    }
  }

  DuelRoomState get room => widget.room;

  bool get _countsValid => room.isSidingCountsValid;

  /// 点主卡组/额外卡组的卡。
  ///
  /// - 没选任何副卡 → 选中这一张（`_selectedMainIndex` + `_selectedZone`）；
  /// - 已选副卡 → 把副卡换进这个分区（一次 move 即完成，见下方说明）。
  void _tapBattleCard(SidingZone zone, int index) {
    final side = room.sidingSide;
    final picked = _selectedSideIndex;
    if (picked != null && side != null && picked < side.length) {
      // 已选副卡 → 先判定这个分区收不收它（额外卡类型只能进额外）。
      final card = side[picked];
      final wantsExtra = zone == SidingZone.extra;
      if (_isExtraDeckCard(card) != wantsExtra) {
        setState(() {
          _error = _isExtraDeckCard(card)
              ? '「${_name(card)}」属于额外卡组，请点额外卡组区域的卡完成互换'
              : '「${_name(card)}」是主卡组卡，请点主卡组区域的卡完成互换';
        });
        return;
      }
      // 副卡进主卡组、主卡进副卡组，用一次原子互换完成。
      widget.onSwapCards(index, picked, zone);
      setState(() {
        _selectedSideIndex = null;
        _selectedMainIndex = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _selectedMainIndex = _selectedMainIndex == index ? null : index;
      _selectedSideIndex = null;
      _error = null;
    });
  }

  /// 点副卡组的卡。
  ///
  /// - 没选任何主卡 → 选中这一张；
  /// - 已选主卡 → 与选中那张原子互换。
  void _tapSideCard(int index) {
    final mainIdx = _selectedMainIndex;
    final main = room.sidingMain;
    final side = room.sidingSide;
    if (mainIdx != null &&
        main != null &&
        mainIdx < main.length &&
        side != null &&
        index < side.length) {
      final zone = _selectedZone;
      final target = side[index];
      if (_isExtraDeckCard(target) != (zone == SidingZone.extra)) {
        setState(() {
          _error = _isExtraDeckCard(target)
              ? '「${_name(target)}」属于额外卡组，请先点额外卡组区域的卡'
              : '「${_name(target)}」是主卡组卡，请先点主卡组区域的卡';
        });
        return;
      }
      widget.onSwapCards(mainIdx, index, zone);
      setState(() {
        _selectedSideIndex = null;
        _selectedMainIndex = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _selectedSideIndex = _selectedSideIndex == index ? null : index;
      _selectedMainIndex = null;
      _error = null;
    });
  }

  /// 当前选中的主卡位于哪个分区（main / extra）。
  SidingZone get _selectedZone {
    final idx = _selectedMainIndex;
    final main = room.sidingMain;
    if (idx == null || main == null) return SidingZone.main;
    return idx < main.length ? SidingZone.main : SidingZone.extra;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final reason = await widget.onSubmit();
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = reason;
    });
  }

  /// 超时自动提交。
  ///
  /// 两个约束决定了不能直接调 [_submit]：
  ///
  /// 1. **换到一半提交必失败**：主/副卡组张数不等时 `confirmSiding` 直接
  ///    返回「数量与基准不一致」。到点瞬间玩家很可能正卡在中间状态，
  ///    先 `onReset` 回退到基准（等于放弃本次调整）再提交才走得通。
  ///    放弃调整是安全的选择——保留一个违规的半成品会让服务端拒收，
  ///    最终被断连，比「这局不换了」糟糕得多。
  /// 2. **可能仍然失败**（禁限表校验、阶段已推进）。此时把原因写进
  ///    `_error`，红色错误条会显示出来；不再重试，避免刷屏。
  Future<void> _submitOnTimeout() async {
    if (_submitting) return;
    // 数量与基准不一致 → 先回退到基准构成。
    final room = widget.room;
    final deck = room.sidingDeck;
    final baseline = room.sidingBaseline;
    final sizeMismatch =
        deck == null ||
        baseline == null ||
        deck.main.length != baseline.main.length ||
        deck.extra.length != baseline.extra.length ||
        deck.side.length != baseline.side.length;
    if (sizeMismatch) {
      widget.onReset();
      // onReset 是同步写 state；等一帧让 widget.room 拿到新值再提交。
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
    }
    if (!mounted) return;
    await _submit();
  }

  @override
  Widget build(BuildContext context) {
    final main = room.sidingMain;
    final extra = room.sidingExtra;
    final side = room.sidingSide;

    if (main == null || extra == null || side == null) {
      return _loadingOrFailed();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final k = (constraints.maxWidth / CyberSideTokens.designSize.width)
            .clamp(0.6, 2.4);
        return Column(
          children: [
            _topBar(),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 左栏：主卡组 + 额外卡组（可滑动，40 格在 390 高度里放不下）。
                    Expanded(flex: 63, child: _battleColumn(k)),
                    const SizedBox(width: 16),
                    // 中栏：副卡组列表。
                    Expanded(flex: 19, child: _sideColumn()),
                    const SizedBox(width: 16),
                    // 右栏：换牌清单 + 双方就绪。
                    Expanded(flex: 22, child: _statusColumn()),
                  ],
                ),
              ),
            ),
            _bottomBar(),
          ],
        );
      },
    );
  }

  Widget _topBar() {
    final seats = PlayerSeats.of(room);
    final me = seats.selfSeat;
    final myName = me == null
        ? null
        : room.players.where((p) => p.pos == me).firstOrNull?.name;
    final opp = seats.right.isNotEmpty ? seats.right.first : null;
    // 倒计时每秒重建：只包顶条，不让整页跟着 1s 刷新。
    return SideCountdown(
      startedAt: room.sidingStartedAt,
      // 到点自动提交：久等会被服务端断开 socket（房间随之关闭），
      // 不能只是把数字归零。
      onExpired: _submitOnTimeout,
      builder: (context, remaining, critical) => SideTopBar(
        title: '换备',
        subtitle: '本地编辑卡组 · 提交后服务端校验',
        accent: CyberSideTokens.cyan,
        gameLabel: room.matchGameLabel,
        myName: myName,
        opponentName: opp?.name,
        myScore: room.myMatchWins,
        opponentScore: room.opponentMatchWins,
        timerText: formatCountdown(remaining),
        timerCritical: critical,
        timerHint: '换备计时',
        timerSubHint: critical ? '即将超时 · 到点自动提交' : '本地计时 · 到点自动提交',
      ),
    );
  }

  /// 左栏：主卡组网格 + 额外卡组横排。
  Widget _battleColumn(double k) {
    final main = room.sidingMain!;
    final extra = room.sidingExtra!;
    final baselineMain = room.sidingBaseline?.main.length ?? main.length;
    final baselineExtra = room.sidingBaseline?.extra.length ?? extra.length;
    final mainShort = baselineMain - main.length;
    final mainFull = main.length == baselineMain;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SideSectionLabel(
          label: 'MAIN DECK · 主卡组',
          trailing: mainFull
              ? '${main.length} / $baselineMain'
              : '${main.length} / $baselineMain · 缺 $mainShort',
          trailingColor: mainFull ? CyberSideTokens.heal : CyberSideTokens.acid,
        ),
        const SizedBox(height: 2),
        Expanded(
          child: SideZoneBox(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _filterRow(main),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: SideCardGrid(
                      items: [for (final c in main) _name(c)],
                      kind: SideCardKind.main,
                      selectedIndex: _selectedMainIndex,
                      pendingCount: mainShort > 0 ? mainShort : 0,
                      onTapIndex: (i) => _tapBattleCard(SidingZone.main, i),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SideSectionLabel(
          label: 'EXTRA DECK · 额外卡组',
          trailing: '${extra.length} / $baselineExtra · 可调整',
          trailingColor: CyberSideTokens.cyan,
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 40,
          child: SideZoneBox(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SideCardGrid(
                      items: [for (final c in extra) _name(c)],
                      kind: SideCardKind.extra,
                      cardWidth: CyberSideTokens.extraCardSize.width,
                      cardHeight: CyberSideTokens.extraCardSize.height,
                      gap: 4,
                      pendingCount: (baselineExtra - extra.length).clamp(
                        0,
                        baselineExtra,
                      ),
                      onTapIndex: (i) => _tapBattleCard(SidingZone.extra, i),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SideText(
                  '额外卡组随 main 段一并提交',
                  size: CyberSideTokens.fsSmall,
                  color: CyberSideTokens.textDim,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 搜索框 + 怪兽/魔陷筛选。
  ///
  /// 设计稿有筛选功能，这里先只做**视觉占位**：点击不生效。换备的卡组
  /// 规模只有 40+15+15，滚动找卡完全够用，实现筛选反而要维护一套
  /// 「过滤后的下标 → 原下标」映射，容易在换卡时点错位置。
  Widget _filterRow(List<CardInfo> main) {
    final monsters = main.where((c) => c.isMonster).length;
    final spells = main.length - monsters;
    return Row(
      children: [
        Container(
          width: 200,
          height: 20,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: CyberSideTokens.barBg,
            border: Border.all(color: CyberSideTokens.controlLine),
            borderRadius: BorderRadius.circular(CyberSideTokens.radius),
          ),
          child: SideText(
            '搜索卡名 / 类型 / 卡片编号',
            size: CyberSideTokens.fsSmall,
            color: CyberSideTokens.textFaint,
          ),
        ),
        const SizedBox(width: 10),
        SideFilterChip(label: '怪兽 $monsters', active: false),
        const SizedBox(width: 8),
        SideFilterChip(label: '魔陷 $spells', active: false),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(right: 2),
          child: SideText(
            '排序',
            size: CyberSideTokens.fsSmall,
            color: CyberSideTokens.textSecondary,
          ),
        ),
      ],
    );
  }

  /// 中栏：副卡组列表。
  Widget _sideColumn() {
    final side = room.sidingSide!;
    final baseline = room.sidingBaseline?.side.length ?? side.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SideSectionLabel(
          label: 'SIDE · 副卡组',
          trailing: '${side.length} 张',
          trailingColor: CyberSideTokens.cyan,
        ),
        const SizedBox(height: 2),
        Expanded(
          child: SideZoneBox(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SideDeckList(
              cards: side,
              subtitleOf: sideCardSubtitle,
              selectedIndex: _selectedSideIndex,
              onTapIndex: _tapSideCard,
              emptyHint: '副卡组 $baseline 张，全部已换入',
            ),
          ),
        ),
      ],
    );
  }

  /// 右栏：换牌清单 + 双方就绪。
  Widget _statusColumn() {
    final swaps = room.sidingSwapList;
    final groups = swaps.inCards.length;
    final main = room.sidingMain!;
    final side = room.sidingSide!;
    final baselineMain = room.sidingBaseline?.main.length ?? main.length;
    final baselineSide = room.sidingBaseline?.side.length ?? side.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SideSectionLabel(label: '换牌清单 · $groups 组'),
        const SizedBox(height: 2),
        SideZoneBox(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _swapColumn('换入', CyberSideTokens.heal, [
                      for (final e in swaps.inCards)
                        '${_codeName(e.code)} ×${e.count}',
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _swapColumn('换出', CyberSideTokens.danger, [
                      for (final e in swaps.outCards)
                        '${_codeName(e.code)} ×${e.count}',
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(height: 1, color: CyberSideTokens.rule),
              const SizedBox(height: 6),
              Row(
                children: [
                  SideText(
                    '主 ${main.length} · 副 ${side.length}',
                    size: CyberSideTokens.fsSmall,
                    color: CyberSideTokens.textSecondary,
                    mono: true,
                  ),
                  const Spacer(),
                  SideText(
                    _countsValid ? '张数守恒 ✓' : '张数待补',
                    size: CyberSideTokens.fsSmall,
                    color: _countsValid
                        ? CyberSideTokens.heal
                        : CyberSideTokens.acid,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  SideText(
                    '基准 主 $baselineMain · 副 $baselineSide',
                    size: CyberSideTokens.fsMicro,
                    color: CyberSideTokens.textDim,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onReset,
                    behavior: HitTestBehavior.opaque,
                    child: SideText(
                      '重置未提交',
                      size: CyberSideTokens.fsSmall,
                      color: CyberSideTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SideSectionLabel(label: 'READY · 双方就绪'),
        const SizedBox(height: 2),
        _readyRow(
          // 统一走 _nameOfSeat：它已按身份给出「我」或中性「玩家 n」兜底，
          // 别在这里再硬编码一个「我」。
          name: _nameOfSeat(PlayerSeats.of(room).selfSeat ?? 0),
          subtitle:
              '主 ${main.length} · 副 ${side.length} · 已换 ${swaps.inCards.length} 组',
          ready: false,
          mine: true,
        ),
        const SizedBox(height: 6),
        _readyRow(
          name: _opponentName(),
          subtitle: '换备中 · 张数不可见',
          ready: room.isOpponentReady,
          mine: false,
        ),
        const Spacer(),
      ],
    );
  }

  Widget _swapColumn(String label, Color color, List<String> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SideText(label, size: CyberSideTokens.fsSmall, color: color),
        const SizedBox(height: 4),
        if (rows.isEmpty)
          SideText(
            '—',
            size: CyberSideTokens.fsMicro,
            color: CyberSideTokens.textDim,
          )
        else
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: SideText(
                r,
                size: CyberSideTokens.fsSmall,
                color: CyberSideTokens.textPrimary,
              ),
            ),
      ],
    );
  }

  Widget _readyRow({
    required String name,
    required String subtitle,
    required bool ready,
    required bool mine,
  }) {
    final color = ready
        ? CyberSideTokens.heal
        : (mine ? CyberSideTokens.cyan : CyberSideTokens.cyan);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: CyberSideTokens.barBg,
        border: Border.all(
          color: ready ? CyberSideTokens.heal : CyberSideTokens.controlLine,
        ),
        borderRadius: BorderRadius.circular(CyberSideTokens.radius),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: CyberSideTokens.cardMainBg,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SideText(
                  name,
                  size: CyberSideTokens.fsLabel,
                  color: CyberSideTokens.textPrimary,
                  weight: FontWeight.w500,
                ),
                SideText(
                  subtitle,
                  size: CyberSideTokens.fsMicro,
                  color: CyberSideTokens.textSecondary,
                ),
              ],
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          SideText(
            ready ? '已提交' : (mine ? '编辑中' : '换备中'),
            size: CyberSideTokens.fsMicro,
            color: color,
          ),
        ],
      ),
    );
  }

  /// 底栏：错误条 + 底注 + 提交/取消。
  Widget _bottomBar() {
    return Container(
      height: CyberSideTokens.bottomBarHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: CyberSideTokens.pagePadding,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: CyberSideTokens.rule)),
      ),
      child: Row(
        children: [
          if (_error != null)
            Expanded(child: _errorBar(_error!))
          else
            const Expanded(
              child: SideText(
                '换备为客户端编辑，提交后由服务端整包校验；主 40 / 额 15 / 副 15，不符将被驳回。',
                size: CyberSideTokens.fsBody,
                color: CyberSideTokens.textDim,
              ),
            ),
          const SizedBox(width: 16),
          SideButton(
            key: const ValueKey('side-decking-submit'),
            label: '提交卡组',
            filled: true,
            loading: _submitting,
            onPressed: _countsValid && !_submitting ? _submit : null,
          ),
          const SizedBox(width: 8),
          SideButton(
            key: const ValueKey('side-decking-cancel'),
            label: '取消编辑',
            onPressed: _submitting ? null : widget.onCancel,
          ),
        ],
      ),
    );
  }

  Widget _errorBar(String message) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: CyberSideTokens.dangerBg,
        border: Border.all(color: CyberSideTokens.danger),
        borderRadius: BorderRadius.circular(CyberSideTokens.radius),
      ),
      child: Row(
        children: [
          SideText(
            '!',
            size: 8,
            color: CyberSideTokens.danger,
            weight: FontWeight.w700,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SideText(
              message,
              size: CyberSideTokens.fsSmall,
              color: CyberSideTokens.danger,
            ),
          ),
        ],
      ),
    );
  }

  /// 卡组数据未就绪：加载中或初始化失败（可重试）。
  Widget _loadingOrFailed() {
    final failed = room.sidingInitFailed;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SideText(
            failed ? '换备数据初始化失败' : '正在准备换备数据…',
            size: CyberSideTokens.fsTitle,
            color: failed
                ? CyberSideTokens.danger
                : CyberSideTokens.textPrimary,
          ),
          const SizedBox(height: 8),
          if (failed)
            SideButton(label: '重试', onPressed: widget.onCancel)
          else
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(CyberSideTokens.cyan),
              ),
            ),
        ],
      ),
    );
  }

  String _opponentName() {
    final seats = PlayerSeats.of(room);
    // 观战者没有「对手」，兜底退回中性称谓。
    final fallback = room.selfType.isDuelist ? '对手' : '玩家 2';
    if (seats.right.isEmpty) return fallback;
    return seats.right.first.name;
  }

  String _nameOfSeat(int seat) {
    final isDuelist = room.selfType.isDuelist;
    for (final p in room.players) {
      if (p.pos == seat) {
        if (p.name.isNotEmpty) return p.name;
        return isDuelist ? '我' : '玩家 ${seat + 1}';
      }
    }
    return isDuelist ? '我' : '玩家 ${seat + 1}';
  }

  /// 卡码 → 卡名（换牌清单用）。从当前草稿 + 基准里找。
  String _codeName(int code) {
    for (final c in [
      ...?room.sidingMain,
      ...?room.sidingExtra,
      ...?room.sidingSide,
    ]) {
      if (c.code == code) return _name(c);
    }
    return '卡片 $code';
  }

  static String _name(CardInfo c) => c.name.isNotEmpty ? c.name : '${c.code}';

  static bool _isExtraDeckCard(CardInfo card) =>
      card.isFusion || card.isSynchro || card.isXyz || card.isLink;
}
