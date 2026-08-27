import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

/// 先后攻提示：居中短暂展示一次，自带淡入 → 停留 → 淡出 → [onDismiss] 的生命周期。
///
/// 调用方负责挂载/定位（通常包一层 `Positioned.fill` + `IgnorePointer` + `Center`），
/// 在 [onDismiss] 回调里把本组件从树中移除即可。
class TurnOrderHint extends StatefulWidget {
  final bool isFirst;

  /// 淡出完成时回调，调用方据此卸载本组件。
  final VoidCallback? onDismiss;

  const TurnOrderHint({super.key, required this.isFirst, this.onDismiss});

  @override
  State<TurnOrderHint> createState() => _TurnOrderHintState();
}

class _TurnOrderHintState extends State<TurnOrderHint> {
  static const _fadeDuration = Duration(milliseconds: 500);
  static const _holdDuration = Duration(milliseconds: 3200);

  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _opacity = 1.0);
    });
    Future.delayed(_holdDuration, () {
      if (!mounted) return;
      setState(() => _opacity = 0.0);
      Future.delayed(_fadeDuration, () {
        if (!mounted) return;
        widget.onDismiss?.call();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFirst = widget.isFirst;
    final accent = isFirst ? Colors.cyanAccent : Colors.amberAccent;
    return AnimatedOpacity(
      opacity: _opacity,
      duration: _fadeDuration,
      curve: Curves.easeOutCubic,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF010308).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.85), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFirst ? Icons.flash_on : Icons.shield,
              color: accent,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              isFirst ? '你先攻' : '你后攻',
              style: TextStyle(
                color: accent,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                fontFamily: 'Orbitron',
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isFirst ? 'First Turn' : 'Second Turn',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontFamily: 'Orbitron',
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _noop() {}

@Preview(name: 'TurnOrderHint — 先攻', size: Size(320, 220))
Widget turnOrderHintFirstPreview() =>
    const TurnOrderHint(isFirst: true, onDismiss: _noop);

@Preview(name: 'TurnOrderHint — 后攻', size: Size(320, 220))
Widget turnOrderHintSecondPreview() =>
    const TurnOrderHint(isFirst: false, onDismiss: _noop);
