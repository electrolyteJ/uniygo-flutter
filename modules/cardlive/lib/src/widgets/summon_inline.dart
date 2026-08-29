import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:resource_data/card_info.dart';
import '../summon_manager.dart';
import '../twod/summon_controller.dart';

/// 点击入口 —— 卡片原地炸开召唤动效
///
/// 在一个 Stack 中覆盖在当前页面上方，带着暗色径向遮罩，
/// 直接从卡片位置爆发展开。
class SummonInline extends StatefulWidget {
  final CardInfo card;
  final String imageUrl;
  final VoidCallback onComplete;

  const SummonInline({
    super.key,
    required this.card,
    required this.imageUrl,
    required this.onComplete,
  });

  @override
  State<SummonInline> createState() => _SummonInlineState();
}

class _SummonInlineState extends State<SummonInline>
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
    _exitController.forward().then((_) => widget.onComplete());
  }

  @override
  Widget build(BuildContext context) {
    final cardName = widget.card.name;
    final controller = SummonController(
      cardImageUrl: widget.imageUrl,
      cardName: cardName,
      category: _manager.deduceType(widget.card),
      onComplete: _handleComplete,
      backgroundAlpha: 0.55, // 半透明，底层列表可见
    );

    return FadeTransition(
      opacity: _exitController.drive(
        Tween(begin: 1.0, end: 0.0),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.7,
            colors: [
              Color(0x60000000), // 中心半透明黑
              Color(0xE6000000), // 边缘近黑
            ],
          ),
        ),
        child: GameWidget(game: controller),
      ),
    );
  }
}

/// 便捷方法：在卡片列表页中内嵌召唤动效
///
/// 使用方式：在 Stack 中根据状态条件添加此 widget。
/// 例如在 [CardListPage] 的 Stack 中：
/// ```dart
/// if (_showInlineSummon && _selectedCard != null)
///   Positioned.fill(
///     child: SummonInline(
///       card: _selectedCard!,
///       imageUrl: _imageUrl,
///       onComplete: () => setState(() => _showInlineSummon = false),
///     ),
///   ),
/// ```
