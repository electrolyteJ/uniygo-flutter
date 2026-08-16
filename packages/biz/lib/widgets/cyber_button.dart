import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

class CyberButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;
  final double? width;

  const CyberButton({
    super.key,
    required this.label,
    this.isPrimary = true,
    required this.onTap,
    this.width,
  });

  @override
  State<CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<CyberButton> {
  bool _isHovered = false;

  /// 延后到帧末再 setState，避免 MouseTracker 设备更新阶段同步 setState
  /// 触发 Flutter 的 !_debugDuringDeviceUpdate 重入断言。
  void _setHovered(bool value) {
    if (_isHovered == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isHovered != value) {
        setState(() => _isHovered = value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const cyanGlow = Color(0xFF00F0FF);
    const blueGradientEnd = Color(0xFF0077B6);

    final gradient = widget.isPrimary
        ? LinearGradient(
            colors: _isHovered
                ? [cyanGlow, const Color(0xFF0077FF)]
                : [cyanGlow.withOpacity(0.3), blueGradientEnd.withOpacity(0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    final borderColor = widget.isPrimary
        ? cyanGlow
        : (_isHovered ? Colors.white : Colors.white.withOpacity(0.2));

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          transform: Matrix4.identity()
            ..translate(0.0, _isHovered ? -2.0 : 0.0, 0.0),
          decoration: BoxDecoration(
            gradient: gradient,
            color: widget.isPrimary ? null : Colors.white.withOpacity(0.06),
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              if (widget.isPrimary || _isHovered)
                BoxShadow(
                  color: cyanGlow.withOpacity(_isHovered ? 0.8 : 0.3),
                  blurRadius: _isHovered ? 25 : 15,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Center(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: (widget.isPrimary || _isHovered)
                          ? Colors.white
                          : const Color(0xFF8B9BB4),
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@Preview(
  name: 'CyberButton primary',
  size: Size(200, 60),
  brightness: Brightness.dark,
)
Widget cyberButtonPrimaryPreview() =>
    const CyberButton(label: '召唤', onTap: _noop);

@Preview(
  name: 'CyberButton secondary',
  size: Size(200, 60),
  brightness: Brightness.dark,
)
Widget cyberButtonSecondaryPreview() =>
    const CyberButton(label: '取消', isPrimary: false, onTap: _noop);

void _noop() {}
