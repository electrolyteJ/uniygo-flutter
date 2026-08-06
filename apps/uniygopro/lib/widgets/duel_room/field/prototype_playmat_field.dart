import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/FieldCard.dart';
import '../../shared/card_image.dart';
import 'playmat_anchor_data.dart';
import 'playmat_field_view_data.dart';

/**
 * PrototypePlaymatField 是一个用于展示游戏场地的 Flutter 组件，支持显示玩家和对手的卡槽、卡牌以及相关信息。它提供了点击事件回调，用于处理卡槽点击和区域点击，并且可以在场地布局发生变化时上报锚点数据。
 */
class PrototypePlaymatField extends StatefulWidget {
  final PlaymatFieldViewData data;
  final void Function(FieldCard? card, int? code)? onFieldCardTap;
  final ValueChanged<String>? onZoneTap;
  final ValueChanged<PlaymatAnchorData>? onAnchorsChanged;

  /// 当前选中的场上卡槽位 id（controller_zone_sequence），用于渲染 v10 的
  /// 青色选中光环 (zone-ring)。
  final String? selectedSlotId;

  const PrototypePlaymatField({
    super.key,
    required this.data,
    this.onFieldCardTap,
    this.onZoneTap,
    this.onAnchorsChanged,
    this.selectedSlotId,
  });

  @override
  State<PrototypePlaymatField> createState() => _PrototypePlaymatFieldState();
}

class _PrototypePlaymatFieldState extends State<PrototypePlaymatField> {
  static const _slotWidth = 68.0;
  static const _slotHeight = 96.0;
  static const _phaseLampSize = Size(132, 44);

  final GlobalKey _rootKey = GlobalKey();
  final Map<String, GlobalKey> _slotKeys = <String, GlobalKey>{};
  String? _lastAnchorSignature;
  bool _anchorEmitQueued = false;

  @override
  void initState() {
    super.initState();
    _scheduleAnchorEmit();
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
    final callback = widget.onAnchorsChanged;
    if (rootContext == null || callback == null) return;
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
    final emz1Rect = slotRects['${widget.data.selfController}_4_5'];
    if (emz1Rect != null) {
      slotRects['${widget.data.opponentController}_4_5'] = emz1Rect;
    }
    final emz2Rect = slotRects['${widget.data.selfController}_4_6'];
    if (emz2Rect != null) {
      slotRects['${widget.data.opponentController}_4_6'] = emz2Rect;
    }

    final phaseLampRect = _buildPhaseLampRect(slotRects, rootBox.size);
    final anchorData = PlaymatAnchorData(
      slotRects: slotRects,
      phaseLampRect: phaseLampRect,
    );
    if (anchorData.signature == _lastAnchorSignature) return;
    _lastAnchorSignature = anchorData.signature;
    callback(anchorData);
  }

  Rect _buildPhaseLampRect(Map<String, Rect> slotRects, Size rootSize) {
    final reference =
        slotRects['self_removed'] ??
        slotRects['self_grave'] ??
        slotRects['${widget.data.selfController}_4_4'];
    if (reference == null) {
      return Rect.fromLTWH(
        rootSize.width * 0.73,
        rootSize.height * 0.53,
        _phaseLampSize.width,
        _phaseLampSize.height,
      );
    }
    return Rect.fromCenter(
      center: Offset(reference.center.dx - 8, reference.center.dy - 42),
      width: _phaseLampSize.width,
      height: _phaseLampSize.height,
    );
  }

  GlobalKey _slotKey(String slotId) {
    return _slotKeys.putIfAbsent(slotId, GlobalKey.new);
  }

  @override
  Widget build(BuildContext context) {
    _scheduleAnchorEmit();
    return Center(
      child: SizedBox.expand(
        key: _rootKey,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // 滚动会改变槽位的实际渲染位置，需要重新上报 anchors，
            // 否则 phase lamp / 场上 action popover 会停留在旧位置。
            _scheduleAnchorEmit();
            return false;
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(0.78)
                ..multiply(Matrix4.diagonal3Values(0.96, 0.96, 1)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 30,
                ),
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
                    _buildSpellTrapRow(
                      controller: widget.data.opponentController,
                    ),
                    const SizedBox(height: 14),
                    _buildMonsterRow(
                      controller: widget.data.opponentController,
                    ),
                    const SizedBox(height: 20),
                    _buildDivider(),
                    const SizedBox(height: 20),
                    _buildEmzRow(),
                    const SizedBox(height: 20),
                    _buildMonsterRow(controller: widget.data.selfController),
                    const SizedBox(height: 14),
                    _buildSpellTrapRow(controller: widget.data.selfController),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpellTrapRow({required int controller}) {
    final isOpponent = controller == widget.data.opponentController;
    final cards = List<Widget>.generate(5, (index) {
      final sequence = isOpponent ? 4 - index : index;
      final label = 'S/T ${isOpponent ? 5 - index : index + 1}';
      return _buildSlot(
        slotId: '${controller}_8_$sequence',
        label: label,
        card: widget.data.cardAt(controller, 8, sequence),
      );
    });

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // v10 布局：己方 [DECK][FIELD][S/T1..5][EX]，对手镜像 [EX][S/T5..1][FIELD][DECK]
        if (!isOpponent) ...[
          _buildZoneEntry(
            slotId: 'self_deck',
            label: 'DECK',
            count: widget.data.selfDeckCount,
          ),
          const SizedBox(width: 12),
        ],
        isOpponent
            ? _buildZoneEntry(
                zoneKey: 'opp_extra',
                slotId: 'opp_extra',
                label: 'EX',
                count: widget.data.oppExtraCount,
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
                zoneKey: 'self_extra',
                slotId: 'self_extra',
                label: 'EX',
                count: widget.data.selfExtraCount,
              ),
        if (isOpponent) ...[
          const SizedBox(width: 12),
          _buildZoneEntry(
            slotId: 'opp_deck',
            label: 'DECK',
            count: widget.data.oppDeckCount,
          ),
        ],
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isOpponent
            ? _buildZoneEntry(
                zoneKey: 'opp_removed',
                slotId: 'opp_removed',
                label: 'BANISH',
                count: widget.data.oppRemovedCount,
              )
            : _buildZoneEntry(
                zoneKey: 'self_grave',
                slotId: 'self_grave',
                label: 'GRAVE',
                count: widget.data.selfGraveCount,
              ),
        const SizedBox(width: 12),
        ..._withGaps(cards),
        const SizedBox(width: 12),
        isOpponent
            ? _buildZoneEntry(
                zoneKey: 'opp_grave',
                slotId: 'opp_grave',
                label: 'GRAVE',
                count: widget.data.oppGraveCount,
              )
            : _buildZoneEntry(
                zoneKey: 'self_removed',
                slotId: 'self_removed',
                label: 'BANISH',
                count: widget.data.selfRemovedCount,
              ),
      ],
    );
  }

  Widget _buildEmzRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 164),
        _buildSlot(
          slotId: '${widget.data.selfController}_4_5',
          label: 'EMZ 1',
          card:
              widget.data.cardAt(widget.data.opponentController, 4, 5) ??
              widget.data.cardAt(widget.data.selfController, 4, 5),
          isEmz: true,
        ),
        const SizedBox(width: 104),
        _buildSlot(
          slotId: '${widget.data.selfController}_4_6',
          label: 'EMZ 2',
          card:
              widget.data.cardAt(widget.data.opponentController, 4, 6) ??
              widget.data.cardAt(widget.data.selfController, 4, 6),
          isEmz: true,
        ),
        const SizedBox(width: 164),
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
  }) {
    final hasCard = card != null && card.code > 0;
    final isSelected = widget.selectedSlotId == slotId;
    return GestureDetector(
      onTap: () => widget.onFieldCardTap?.call(card, card?.code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        key: _slotKey(slotId),
        width: _slotWidth,
        height: _slotHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hasCard
              ? Colors.black
              : (isEmz ? const Color(0x14FFD700) : const Color(0x0F00F0FF)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00F0FF)
                : hasCard
                ? Colors.white.withValues(alpha: 0.56)
                : (isEmz ? const Color(0x99FFD700) : const Color(0x5900F0FF)),
            width: isSelected ? 2 : 1.3,
          ),
          boxShadow: [
            if (isSelected)
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
    final isFacedown = (card.position & _posFacedownMask) != 0;
    final isDefense = (card.position & _posDefenseMask) != 0;

    Widget face = isFacedown
        ? const _CardBack()
        : CardImage(code: card.code, width: _slotWidth, height: _slotHeight);

    if (isDefense) {
      // 守备表示：卡图旋转 90°，等比缩小避免溢出槽位
      face = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateZ(math.pi / 2)
          ..scaleByDouble(0.74, 0.74, 1.0, 1.0),
        child: face,
      );
    }

    return Stack(
      fit: StackFit.expand,
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
  }) {
    return GestureDetector(
      onTap: zoneKey == null ? null : () => widget.onZoneTap?.call(zoneKey),
      child: Container(
        key: _slotKey(slotId),
        width: _slotWidth,
        height: _slotHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
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
class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF31475E), Color(0xFF0A1020)],
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
