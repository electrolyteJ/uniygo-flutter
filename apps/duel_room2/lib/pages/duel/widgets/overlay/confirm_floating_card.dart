import 'package:flutter/material.dart';

import 'package:biz/widgets/card_image.dart';

/// 卡组顶部 / 额外卡组顶部 确认展示的浮动卡片。
///
/// 参考经典 ygopro C++ 客户端：卡片偏移 + 旋转展示后自动复位。
/// Flutter 中以浮动卡片 + 缩放动效模拟。
class ConfirmFloatingCard extends StatefulWidget {
  final List<int> codes;
  final String title;
  final String Function(int code) cardNameBuilder;
  final VoidCallback? onDismiss;
  final double autoCloseSeconds;

  const ConfirmFloatingCard({
    super.key,
    required this.codes,
    required this.title,
    required this.cardNameBuilder,
    this.onDismiss,
    this.autoCloseSeconds = 2.0,
  });

  @override
  State<ConfirmFloatingCard> createState() => _ConfirmFloatingCardState();
}

class _ConfirmFloatingCardState extends State<ConfirmFloatingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: (widget.autoCloseSeconds * 1000).round()),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.3)),
    );

    _controller.forward();

    if (widget.codes.length > 1) {
      final interval = widget.autoCloseSeconds / widget.codes.length;
      for (int i = 1; i < widget.codes.length; i++) {
        Future.delayed(
          Duration(milliseconds: (interval * i * 1000).round()), () {
          if (mounted) {
            setState(() => _currentIndex = i);
            _controller.reset();
            _controller.forward();
          }
        },
        );
      }
    }

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        if (_currentIndex >= widget.codes.length - 1) {
          Future.delayed(const Duration(milliseconds: 300), () {
            widget.onDismiss?.call();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.codes[_currentIndex];
    final name = widget.cardNameBuilder(code);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnim.value,
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onDismiss,
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xF2080C14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00F0FF),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CardImage(
                  code: code,
                  width: 130,
                  height: 186,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD7E3F2),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Noto Sans SC',
                  height: 1.25,
                ),
              ),
              if (widget.codes.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.codes.length}',
                    style: const TextStyle(
                      color: Color(0xFF8B9BB4),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
