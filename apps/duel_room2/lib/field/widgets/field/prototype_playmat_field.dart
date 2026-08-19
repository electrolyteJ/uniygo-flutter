import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:biz/widgets/card_image.dart';
import 'package:biz/duel/models/field_card.dart';
import '../duel_shuffle_shake.dart';
import 'duel_field_background.dart';
import 'duel_field_layout.dart';
import 'phase_lamp.dart';
import 'package:biz/duel/models/playmat_anchor_data.dart';
import 'package:duel_room2/field/models/playmat_field_view_data.dart';

/// PrototypePlaymatField 是一个用于展示游戏场地的 Flutter 组件，
/// 支持显示玩家和对手的卡槽、卡牌以及相关信息。
/// 它提供了点击事件回调，用于处理卡槽点击和区域点击，
/// 并且可以在场地布局发生变化时上报锚点数据。
class PrototypePlaymatField extends StatefulWidget {
  final PlaymatFieldViewData data;
  final void Function(FieldCard? card, int? code)? onFieldCardTap;
  final ValueChanged<String>? onZoneTap;
  final ValueChanged<PlaymatAnchorData>? onAnchorsChanged;

  /// 当前选中的场上卡槽位 id（controller_zone_sequence），用于渲染 v10 的
  /// 青色选中光环 (zone-ring)。
  final String? selectedSlotId;

  /// 就地选择（连锁/选卡/解放等）中可点击的槽位 id 集合。
  final Set<String> selectableSlotIds;

  /// 就地选择多选中已勾选的槽位 id 集合。
  final Set<String> checkedSlotIds;

  /// 放置选择（MSG_SELECT_PLACE）中的可放置空槽位 id 集合。
  final Set<String> placeTargetSlotIds;

  /// 确认展示（MSG_CONFIRM_CARDS 场上卡）时需要高亮的槽位 id 集合。
  final Set<String> confirmedSlotIds;

  /// 当前窗口下「有可发动/可召唤卡」的区域 key（self_grave / self_extra 等），
  /// 用于在墓地/除外/额外区域渲染高亮提醒（智能打牌反馈）。
  final Set<String> activatableZoneKeys;

  /// 主卡组洗切信号（tick + 玩家），驱动 DECK 区域抖动。
  final int deckShuffleTick;
  final int deckShufflePlayer;

  /// 额外卡组洗切信号（tick + 玩家），驱动 EXTRA 区域抖动。
  final int extraShuffleTick;
  final int extraShufflePlayer;

  /// 点击可放置槽位的回调（槽位 id 为 `controller_zone_sequence`）。
  final void Function(String slotId)? onPlaceSlotTap;

  /// 阶段指示灯数据：阶段、是否可点击、点击回调。
  /// PhaseLamp 直接在字段内渲染（定位到 self_grave / 我方墓地卡槽右上角）。
  final DuelPhase phase;
  final bool phaseLampEnabled;
  final VoidCallback? onPhaseLampTap;

  const PrototypePlaymatField({
    super.key,
    required this.data,
    required this.phase,
    this.phaseLampEnabled = false,
    this.onPhaseLampTap,
    this.onFieldCardTap,
    this.onZoneTap,
    this.onAnchorsChanged,
    this.selectedSlotId,
    this.selectableSlotIds = const {},
    this.checkedSlotIds = const {},
    this.placeTargetSlotIds = const {},
    this.confirmedSlotIds = const {},
    this.activatableZoneKeys = const {},
    this.deckShuffleTick = 0,
    this.deckShufflePlayer = 0,
    this.extraShuffleTick = 0,
    this.extraShufflePlayer = 0,
    this.onPlaceSlotTap,
  });

  @override
  State<PrototypePlaymatField> createState() => _PrototypePlaymatFieldState();
}

class _PrototypePlaymatFieldState extends State<PrototypePlaymatField>
    with SingleTickerProviderStateMixin {
  static final _slotWidth = DuelFieldLayout.slotWidth;
  static final _slotHeight = DuelFieldLayout.slotHeight;
  static final _phaseLampSize = DuelFieldLayout.phaseLampSize;

  /// 沉浸式布局：棋盘内容在「扣除 HUD 的可用区」内 FittedBox 铺满。
  /// 数值与 [DuelFieldPage] 的 HUD Positioned 对齐，左右为状态卡对称预留
  /// （不考虑检查器展开的覆盖）。
  static const _horizontalReserved = 96.0;
  static const _topReserved = 230.0; // 顶部 HUD + 对手手牌预留
  static const _bottomReserved = 96.0; // 自己手牌栏高 96

  final GlobalKey _rootKey = GlobalKey();
  final Map<String, GlobalKey> _slotKeys = <String, GlobalKey>{};
  String? _lastAnchorSignature;
  bool _anchorEmitQueued = false;
  Rect? _phaseLampRect;

  /// 可发动区域金点的脉冲动画（0.4↔1.0 呼吸）。
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.4,
      upperBound: 1.0,
    )..repeat(reverse: true);
    _scheduleAnchorEmit();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PrototypePlaymatField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.onAnchorsChanged != widget.onAnchorsChanged) {
      _scheduleAnchorEmit();
    }
  }

  void _scheduleAnchorEmit() {
    if (_anchorEmitQueued) return;
    _anchorEmitQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _anchorEmitQueued = false;
      if (!mounted) return;
      _emitAnchors();
    });
  }

  void _emitAnchors() {
    final rootContext = _rootKey.currentContext;
    if (rootContext == null) return;
    final rootBox = rootContext.findRenderObject() as RenderBox?;
    if (rootBox == null || !rootBox.hasSize) return;

    final slotRects = <String, Rect>{};
    for (final entry in _slotKeys.entries) {
      final context = entry.value.currentContext;
      if (context == null) continue;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final topLeft = box.localToGlobal(Offset.zero, ancestor: rootBox);
      slotRects[entry.key] = topLeft & box.size;
    }
    // EMZ 双方共享且序列镜像：己方 5 与对方 6 是同一物理槽位，己方 6 与对方 5 同槽。
    final emz1Rect = slotRects['${widget.data.selfController}_4_5'];
    if (emz1Rect != null) {
      slotRects['${widget.data.opponentController}_4_6'] = emz1Rect;
    }
    final emz2Rect = slotRects['${widget.data.selfController}_4_6'];
    if (emz2Rect != null) {
      slotRects['${widget.data.opponentController}_4_5'] = emz2Rect;
    }

    final phaseLampRect = _buildPhaseLampRect(slotRects, rootBox.size);

    // 上报 anchors（供 page 的 PhaseActionMenu / FieldActionPopover 定位）
    final callback = widget.onAnchorsChanged;
    if (callback != null) {
      final anchorData = PlaymatAnchorData(
        slotRects: slotRects,
        phaseLampRect: phaseLampRect,
      );
      if (anchorData.signature != _lastAnchorSignature) {
        _lastAnchorSignature = anchorData.signature;
        callback(anchorData);
      }
    }

    // 本地 PhaseLamp 渲染：rect 变化时触发重建
    if (_phaseLampRect != phaseLampRect) {
      _phaseLampRect = phaseLampRect;
      setState(() {});
    }
  }

  Rect _buildPhaseLampRect(Map<String, Rect> slotRects, Size rootSize) {
    // 锚点优先级：self_removed（除外/Banish，EMZ行右 colX[6]）→ self_grave（墓地 Monster行右）→ M4
    // 与 DuelFieldLayout.phaseLampRefBoardX/Y 对齐。
    final reference =
        slotRects['self_removed'] ??
        slotRects['self_grave'] ??
        slotRects['${widget.data.selfController}_4_0'];
    if (reference == null) {
      return Rect.fromLTWH(
        rootSize.width * DuelFieldLayout.phaseLampFallbackRatio.dx,
        rootSize.height * DuelFieldLayout.phaseLampFallbackRatio.dy,
        _phaseLampSize.width,
        _phaseLampSize.height,
      );
    }
    // PhaseLamp 左下角 = self_grave 卡槽右上角 + (gap, -gap)。
    // reference 是 FittedBox 缩放后的视口 rect，gap 为固定像素间距，
    // 故定位与缩放比例无关，lamp 始终贴在卡槽右上角外侧。
    final gap = DuelFieldLayout.phaseLampGap;
    return Rect.fromLTWH(
      reference.right + gap,
      reference.top - gap - _phaseLampSize.height,
      _phaseLampSize.width,
      _phaseLampSize.height,
    );
  }

  GlobalKey _slotKey(String slotId) {
    return _slotKeys.putIfAbsent(slotId, GlobalKey.new);
  }

  @override
  Widget build(BuildContext context) {
    _scheduleAnchorEmit();
    const h = _horizontalReserved;
    return SizedBox.expand(
      key: _rootKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // v10 装饰背景：渐变光晕 + vignette（原型模式专属），铺满全视口。
          const Positioned.fill(child: DuelFieldBackground()),
          // 棋盘内容在「扣除状态卡(水平) + 上下手牌栏」的可用区内 FittedBox 铺满：
          // 既最大化放大（沉浸），又避免与左右状态卡、上下手牌栏重叠。
          // _rootKey 在视口级 SizedBox 上，slotRects 经 localToGlobal 反映
          // FittedBox 缩放后的实际视口坐标，page 的 popover 定位正确。
          Positioned(
            left: h,
            top: _topReserved,
            right: h,
            bottom: _bottomReserved,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: _buildBoardContent(),
            ),
          ),
          // PhaseLamp 固定尺寸（不随 FittedBox 缩放），保持可读可点；
          // 定位基于 self_grave 卡槽的视口 rect 右上角 + gap。
          if (_phaseLampRect != null)
            Positioned(
              left: _phaseLampRect!.left,
              top: _phaseLampRect!.top,
              child: PhaseLamp(
                phase: widget.phase,
                enabled: widget.phaseLampEnabled,
                onTap: widget.onPhaseLampTap,
              ),
            ),
        ],
      ),
    );
  }

  /// 棋盘内容（装饰容器 + 卡槽列），保持自然尺寸，由外层 FittedBox 缩放。
  Widget _buildBoardContent() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x7300F0FF), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
        gradient: const RadialGradient(
          center: Alignment(0, -0.15),
          radius: 1.15,
          colors: [Color(0x1F00F0FF), Color(0xF1060A12)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSpellTrapRow(controller: widget.data.opponentController),
          const SizedBox(height: 4),
          _buildMonsterRow(controller: widget.data.opponentController),
          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 20),
          _buildEmzRow(),
          const SizedBox(height: 20),
          _buildMonsterRow(controller: widget.data.selfController),
          const SizedBox(height: 4),
          _buildSpellTrapRow(controller: widget.data.selfController),
        ],
      ),
    );
  }

  Widget _buildSpellTrapRow({required int controller}) {
    final isOpponent = controller == widget.data.opponentController;
    final deckTick = widget.deckShufflePlayer == controller
        ? widget.deckShuffleTick
        : 0;
    final extraTick = widget.extraShufflePlayer == controller
        ? widget.extraShuffleTick
        : 0;
    final cards = List<Widget>.generate(5, (index) {
      final sequence = isOpponent ? 4 - index : index;
      final label = 'S/T ${isOpponent ? 5 - index : index + 1}';
      return _buildSlot(
        slotId: '${controller}_8_$sequence',
        label: label,
        card: widget.data.cardAt(controller, 8, sequence),
      );
    });

    // SpellTrap 行：EXTRA / S/T1..5 / DECK，紧贴怪兽行。
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isOpponent
            ? _buildZoneEntry(
                slotId: 'opp_deck',
                label: 'DECK',
                count: widget.data.oppDeckCount,
                showCardBack: true,
                showCount: false,
                shuffleTick: deckTick,
              )
            : _buildZoneEntry(
                zoneKey: 'self_extra',
                slotId: 'self_extra',
                label: 'EXTRA',
                count: widget.data.selfExtraCount,
                topCardCode: widget.data.selfExtraTopCode,
                showTopCard: true,
                showCount: false,
                shuffleTick: extraTick,
              ),
        const SizedBox(width: 12),
        ..._withGaps(cards),
        const SizedBox(width: 12),
        isOpponent
            ? _buildZoneEntry(
                zoneKey: 'opp_extra',
                slotId: 'opp_extra',
                label: 'EXTRA',
                count: widget.data.oppExtraCount,
                topCardCode: widget.data.oppExtraTopCode,
                showTopCard: true,
                showCount: false,
                shuffleTick: extraTick,
              )
            : _buildZoneEntry(
                slotId: 'self_deck',
                label: 'DECK',
                count: widget.data.selfDeckCount,
                showCardBack: true,
                showCount: false,
                shuffleTick: deckTick,
              ),
      ],
    );
  }

  Widget _buildMonsterRow({required int controller}) {
    final isOpponent = controller == widget.data.opponentController;
    final cards = List<Widget>.generate(5, (index) {
      final sequence = isOpponent ? 4 - index : index;
      final label = 'M ${isOpponent ? 5 - index : index + 1}';
      return _buildSlot(
        slotId: '${controller}_4_$sequence',
        label: label,
        card: widget.data.cardAt(controller, 4, sequence),
      );
    });

    // Monster 行：FIELD 与 M1..5 保持同一水平线。
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isOpponent
            ? _buildZoneEntry(
                zoneKey: 'opp_grave',
                slotId: 'opp_grave',
                label: 'GRAVE',
                count: widget.data.oppGraveCount,
                topCardCode: widget.data.oppGraveTopCode,
                showTopCard: true,
                showCount: false,
              )
            : _buildSlot(
                slotId: '${controller}_8_5',
                label: 'FIELD',
                card: widget.data.cardAt(controller, 8, 5),
              ),
        const SizedBox(width: 12),
        ..._withGaps(cards),
        const SizedBox(width: 12),
        isOpponent
            ? _buildSlot(
                slotId: '${controller}_8_5',
                label: 'FIELD',
                card: widget.data.cardAt(controller, 8, 5),
              )
            : _buildZoneEntry(
                zoneKey: 'self_grave',
                slotId: 'self_grave',
                label: 'GRAVE',
                count: widget.data.selfGraveCount,
                topCardCode: widget.data.selfGraveTopCode,
                showTopCard: true,
                showCount: false,
              ),
      ],
    );
  }

  Widget _buildEmzRow() {
    // 新布局：BANISH 移至本行，与 EM1/EM2 同一水平。
    // 己方视角从左→右：[对手BANISH][EMZ 1][EMZ 2][己方BANISH]
    // 对应 colX：[0] [2]=-84 [4]=+84 [6]，列间距 84，槽宽 68 → 相邻槽边距=84*2-68=100
    const gap = 100.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildZoneEntry(
          zoneKey: 'opp_removed',
          slotId: 'opp_removed',
          label: 'BANISH',
          count: widget.data.oppRemovedCount,
          topCardCode: widget.data.oppRemovedTopCode,
          showTopCard: true,
          showCount: false,
        ),
        const SizedBox(width: gap),
        _buildSlot(
          slotId: '${widget.data.selfController}_4_5',
          altSlotIds: ['${widget.data.opponentController}_4_6'],
          label: 'EMZ 1',
          card:
              widget.data.cardAt(widget.data.selfController, 4, 5) ??
              widget.data.cardAt(widget.data.opponentController, 4, 6),
          isEmz: true,
        ),
        const SizedBox(width: gap),
        _buildSlot(
          slotId: '${widget.data.selfController}_4_6',
          altSlotIds: ['${widget.data.opponentController}_4_5'],
          label: 'EMZ 2',
          card:
              widget.data.cardAt(widget.data.selfController, 4, 6) ??
              widget.data.cardAt(widget.data.opponentController, 4, 5),
          isEmz: true,
        ),
        const SizedBox(width: gap),
        _buildZoneEntry(
          zoneKey: 'self_removed',
          slotId: 'self_removed',
          label: 'BANISH',
          count: widget.data.selfRemovedCount,
          topCardCode: widget.data.selfRemovedTopCode,
          showTopCard: true,
          showCount: false,
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 540,
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [
            Colors.transparent,
            Color(0x7A00F0FF),
            Color(0xB5FFFFFF),
            Color(0x7A00F0FF),
            Colors.transparent,
          ],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x6600F0FF), blurRadius: 18, spreadRadius: 1),
        ],
      ),
    );
  }

  Widget _buildSlot({
    required String slotId,
    required String label,
    required FieldCard? card,
    bool isEmz = false,
    List<String> altSlotIds = const [],
  }) {
    // 里侧卡（尤其是对方里侧卡）code 为 0（对端隐藏），但仍占槽且应渲染卡背，
    // 不能因 code==0 当成空槽。
    final hasCard = card != null;
    final isSelected = widget.selectedSlotId == slotId;
    // 高亮与点击落在槽位本身：就地选择（连锁/选卡/解放等）与
    // 放置选择（MSG_SELECT_PLACE）不再由页面覆盖层绘制。
    // EMZ 为双方共享的物理槽位，需同时匹配双方 controller 的 key。
    final matchIds = [slotId, ...altSlotIds];
    final isChecked = matchIds.any(widget.checkedSlotIds.contains);
    final isSelectable =
        !isChecked && matchIds.any(widget.selectableSlotIds.contains);
    final isConfirmed =
        !isChecked &&
        !isSelectable &&
        matchIds.any(widget.confirmedSlotIds.contains);
    String? placeTargetId;
    if (!isChecked && !isSelectable) {
      for (final id in matchIds) {
        if (widget.placeTargetSlotIds.contains(id)) {
          placeTargetId = id;
          break;
        }
      }
    }
    final placeSlotId = placeTargetId;
    final isPlaceTarget = placeSlotId != null;
    return GestureDetector(
      onTap: isPlaceTarget
          ? () => widget.onPlaceSlotTap?.call(placeSlotId)
          : () => widget.onFieldCardTap?.call(card, card?.code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        key: _slotKey(slotId),
        width: _slotWidth,
        height: _slotHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isChecked
              ? const Color(0x40FFD700)
              : isConfirmed
              ? const Color(0x22FFFFFF)
              : (isSelectable || isPlaceTarget)
              ? const Color(0x1F00F0FF)
              : hasCard
              ? Colors.transparent
              : (isEmz ? const Color(0x14FFD700) : const Color(0x0F00F0FF)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isChecked
                ? const Color(0xFFFFD700)
                : isConfirmed
                ? Colors.white.withValues(alpha: 0.85)
                : (isSelectable || isPlaceTarget)
                ? const Color(0xFF00F0FF)
                : isSelected
                ? const Color(0xFF00F0FF)
                : hasCard
                ? Colors.white.withValues(alpha: 0.56)
                : (isEmz ? const Color(0x99FFD700) : const Color(0x5900F0FF)),
            width: isChecked
                ? 2.5
                : isConfirmed
                ? 3.0
                : (isSelectable || isPlaceTarget || isSelected)
                ? 2
                : 1.3,
          ),
          boxShadow: [
            if (isChecked)
              const BoxShadow(color: Color(0x66FFD700), blurRadius: 22),
            if (isConfirmed)
              const BoxShadow(color: Color(0x88FFFFFF), blurRadius: 30),
            if (isSelectable || isPlaceTarget || isSelected)
              const BoxShadow(color: Color(0x6600F0FF), blurRadius: 22),
            BoxShadow(
              color: (isEmz
                  ? const Color(0x44FFD700)
                  : const Color(0x2200F0FF)),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: hasCard
            ? _buildSlotCard(card)
            : Text(
                label,
                style: const TextStyle(
                  color: Color(0x99FFFFFF),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Orbitron',
                  letterSpacing: 0.8,
                ),
              ),
      ),
    );
  }

  // 位置位掩码：0x1 表攻 / 0x2 里攻 / 0x4 表守 / 0x8 里守
  static const int _posFacedownMask = 0x0A;
  static const int _posDefenseMask = 0x0C;

  Widget _buildSlotCard(FieldCard card) {
    // 兜底：code<=0（对端里侧卡）必按里侧渲染卡背，避免极端情况下面朝上。
    final isFacedown =
        card.code <= 0 || (card.position & _posFacedownMask) != 0;
    final isDefense = (card.position & _posDefenseMask) != 0;

    // 守备表示（表侧/里侧）横放：整卡旋转 90° 得到横图，再缩放到槽宽，
    // 上下留出透明区域（槽背景已透明，不再是黑色填充）。
    final sideways = isDefense && card.zone == 4;

    Widget face = SizedBox(
      width: _slotWidth,
      height: _slotHeight,
      child: isFacedown
          ? const _CardBack()
          : CardImage(code: card.code, width: _slotWidth, height: _slotHeight),
    );

    if (sideways) {
      face = FittedBox(
        fit: BoxFit.contain,
        child: RotatedBox(quarterTurns: 1, child: face),
      );
    }

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        face,
        if (!isFacedown && card.zone == 4) _buildPositionBadge(card),
      ],
    );
  }

  Widget _buildPositionBadge(FieldCard card) {
    final isDefense = (card.position & _posDefenseMask) != 0;
    final value = isDefense ? card.defense : card.attack;
    final label = isDefense ? 'DEF' : 'ATK';
    final color = isDefense ? const Color(0xFF00F0FF) : const Color(0xFFFF6193);
    return Positioned(
      right: 3,
      top: 3,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.62)),
        ),
        child: Text(
          value == null ? label : '$label $value',
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            fontFamily: 'Orbitron',
          ),
        ),
      ),
    );
  }

  Widget _buildZoneEntry({
    required String slotId,
    String? zoneKey,
    required String label,
    required int count,
    bool showCardBack = false,
    bool showCount = true,
    int topCardCode = 0,
    bool showTopCard = false,
    int shuffleTick = 0,
  }) {
    final Widget entryChild;
    if (showCardBack) {
      entryChild = const _CardBack();
    } else if (showTopCard) {
      entryChild = topCardCode > 0
          ? CardImage(
              code: topCardCode,
              width: _slotWidth - 2,
              height: _slotHeight - 2,
            )
          : const SizedBox.shrink();
    } else {
      entryChild = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8B9BB4),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              fontFamily: 'Orbitron',
            ),
          ),
          if (showCount) ...[
            const SizedBox(height: 4),
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontFamily: 'Orbitron',
              ),
            ),
          ],
        ],
      );
    }

    final isActivatable =
        zoneKey != null && widget.activatableZoneKeys.contains(zoneKey);
    return ShuffleShake(
      tick: shuffleTick,
      child: GestureDetector(
        onTap: zoneKey == null ? null : () => widget.onZoneTap?.call(zoneKey),
        child: Container(
          key: _slotKey(slotId),
          width: _slotWidth,
          height: _slotHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActivatable
                ? const Color(0x22FFD700)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActivatable
                  ? const Color(0xFFFFD700)
                  : Colors.white.withValues(alpha: 0.18),
              width: isActivatable ? 1.8 : 1,
            ),
            boxShadow: [
              if (isActivatable)
                const BoxShadow(color: Color(0x66FFD700), blurRadius: 18),
              const BoxShadow(
                color: Color(0x22000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: isActivatable
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    entryChild,
                    Positioned(
                      right: 2,
                      top: 2,
                      child: FadeTransition(
                        opacity: _pulseController,
                        child: const _ActivatableDot(),
                      ),
                    ),
                  ],
                )
              : entryChild,
        ),
      ),
    );
  }

  List<Widget> _withGaps(List<Widget> children) {
    final result = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        result.add(const SizedBox(width: 12));
      }
      result.add(children[index]);
    }
    return result;
  }
}

/// 里侧表示卡背（v10 opp-card-back 风格）
/// 可发动区域提示点：当墓地/除外/额外有可发动/可召唤卡时显示的金色圆点。
class _ActivatableDot extends StatelessWidget {
  const _ActivatableDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Color(0xFFFFD700),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0xAAFFD700), blurRadius: 6)],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D5A73), Color(0xFF1E2F45)],
        ),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0xFF00F0FF), width: 1.2),
        ),
      ),
      child: Center(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x5900F0FF)),
          ),
        ),
      ),
    );
  }
}

@Preview(
  name: 'PrototypePlaymatField',
  size: Size(900, 620),
  brightness: Brightness.dark,
)
Widget previewPrototypePlaymatField() => const PrototypePlaymatField(
  data: PlaymatFieldViewData(
    fieldCards: {},
    selfController: 0,
    opponentController: 1,
    selfDeckCount: 40,
    selfExtraCount: 5,
    selfGraveCount: 3,
    selfRemovedCount: 1,
    oppDeckCount: 40,
    oppExtraCount: 5,
    oppGraveCount: 2,
    oppRemovedCount: 0,
  ),
  phase: DuelPhase.m1,
);
