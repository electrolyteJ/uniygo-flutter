import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:ygo_data/card_info.dart';
import 'summon_controller.dart';
import 'summon_manager.dart';

/// 长按入口 —— 半透明 Overlay 全屏召唤动效
///
/// 用法：
/// ```dart
/// Navigator.of(context).push(
///   PageRouteBuilder(
///     opaque: false,
///     pageBuilder: (_, __, ___) => SummonOverlay(
///       card: card,
///       imageUrl: url,
///       onBack: () => Navigator.of(context).pop(),
///     ),
///     transitionsBuilder: (_, anim, __, child) =>
///         FadeTransition(opacity: anim, child: child),
///   ),
/// );
/// ```
class SummonOverlay extends StatefulWidget {
  final CardInfo card;
  final String imageUrl;
  final VoidCallback onBack;

  const SummonOverlay({
    super.key,
    required this.card,
    required this.imageUrl,
    required this.onBack,
  });

  @override
  State<SummonOverlay> createState() => _SummonOverlayState();
}

class _SummonOverlayState extends State<SummonOverlay>
    with SingleTickerProviderStateMixin {
  late final SummonManager _manager;
  late final AnimationController _exitController;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _manager = SummonManager.instance;
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _exitController.dispose();
    super.dispose();
  }

  void _handleComplete() {
    if (_dismissing) return;
    _dismissing = true;
    _exitController.forward().then((_) => widget.onBack());
  }

  void _handleManualDismiss() {
    if (_dismissing) return;
    _dismissing = true;
    _exitController.forward().then((_) => widget.onBack());
  }

  @override
  Widget build(BuildContext context) {
    final cardName = widget.card.name;
    final controller = SummonController(
      cardImageUrl: widget.imageUrl,
      cardName: cardName,
      summonType: _manager.deduceType(widget.card),
      onComplete: _handleComplete,
    );

    return FadeTransition(
      opacity: _exitController.drive(
        Tween(begin: 1.0, end: 0.0),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Flame 游戏
          GameWidget(game: controller),

          // 关闭按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: GestureDetector(
              onTap: _handleManualDismiss,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white70, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
